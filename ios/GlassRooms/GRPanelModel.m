#import "GRPanelModel.h"
#import "GRLogic.h"
#import "GRUtil.h"

static const NSTimeInterval GRPollInterval = 30;

@interface GRPanelModel ()
@property (nonatomic, strong, readwrite) GRAPIClient *client;
@property (nonatomic, readwrite) BOOL connected, preview, demo, liveUpdates, busy, authenticated;
@property (nonatomic, readwrite, copy) NSArray<NSDictionary *> *entities;
@property (nonatomic, readwrite, copy) NSString *fetchedAt, *error, *configurationProblem;
@property (nonatomic, readwrite) NSInteger historyHours;
@property (nonatomic, readwrite, copy) NSDictionary *historySeries;
@property (nonatomic, readwrite) BOOL historyLoading;
@property (nonatomic, readwrite, copy) NSString *historyError;
@end

@implementation GRPanelModel {
  BOOL _loading, _background, _pendingUpdate, _pendingForce;
  GRTimer *_pollTimer, *_updateRetryTimer;
  NSMutableArray<GRTimer *> *_actionRefreshTimers;
  NSDictionary *_pendingConfirmation;
  NSURLSessionDataTask *_updateTask, *_historyTask;
  long long _updateRevision;
  NSUInteger _updateGeneration, _historyGeneration, _clientGeneration;
  NSTimeInterval _historyLoadedAt;
}

- (instancetype)init {
  if((self = [super init])) {
    _entities = @[];
    _historyHours = 24;
    _historySeries = @{};
    _actionRefreshTimers = [NSMutableArray array];
  }
  return self;
}

#pragma mark - Lifecycle

- (void)useClient:(GRAPIClient *)client {
  [self stopEverything];
  [self.client invalidate];
  _clientGeneration++;
  self.client = client;
  self.authenticated = NO; self.preview = NO; self.demo = NO;
  [self clearState];
  self.configurationProblem = client ? nil : @"Escriu l’adreça del panell i el token de l’app (app_token) i toca «Desa i connecta».";
  [self.delegate panelModel:self didUpdateWithForce:YES changed:YES];
  if(client) { [self session]; }
  else { [self.delegate panelModel:self needsConfiguration:self.configurationProblem]; }
}

- (void)clearState {
  self.connected = NO; self.liveUpdates = NO; self.entities = @[]; self.fetchedAt = nil; self.error = nil;
  [self resetHistory];
}

- (void)stopEverything {
  [_pollTimer cancel]; _pollTimer = nil;
  [self clearActionRefreshes];
  [self stopUpdateListener];
  [_historyTask cancel]; _historyTask = nil; _historyGeneration++;
  _loading = NO; _pendingUpdate = NO; _pendingForce = NO;
}

- (void)enterBackground {
  _background = YES;
  [_pollTimer cancel]; _pollTimer = nil;
  [self stopUpdateListener];
}

- (void)enterForeground {
  _background = NO;
  if(!self.client) { return; }
  if(!self.authenticated && !self.preview) { [self session]; return; }
  [self refresh:NO];
  [self listenForUpdates];
}

#pragma mark - Session and state

- (void)session {
  if(_loading || !self.client) { return; }
  _loading = YES;
  NSUInteger generation = _clientGeneration;
  [self.client GET:@"/api/session" timeout:15 completion:^(NSString *error, id data, NSInteger status) {
    if(generation != self->_clientGeneration) { return; }
    self->_loading = NO;
    if(status == 401) { [self requireConfiguration:error]; return; }
    if(error) {
      self.error = [error stringByAppendingString:@" Comprova que l’adreça apunta al servidor del panell (normalment port 8099)."];
      self.connected = NO;
      [self.delegate panelModel:self didUpdateWithForce:YES changed:YES];
      [self->_pollTimer cancel];
      __weak GRPanelModel *weakSelf = self;
      self->_pollTimer = [GRTimer after:12 block:^{ [weakSelf session]; }];
      return;
    }
    self.preview = [data[@"preview"] isEqual:@YES];
    self.authenticated = [data[@"authenticated"] isEqual:@YES];
    if(self.authenticated || self.preview) { self.configurationProblem = nil; [self refresh:NO]; }
    else {
      [self requireConfiguration:self.client.hasToken
        ? @"El servidor no accepta el token. Actualitza Glass Rooms a 1.1.4 o posterior i revisa app_token."
        : @"Introdueix el token de l’app (app_token) i toca «Desa i connecta»."];
    }
  }];
}

- (void)requireConfiguration:(NSString *)reason {
  [self stopEverything];
  self.authenticated = NO;
  [self clearState];
  self.configurationProblem = reason.length ? reason : @"Revisa la connexió a Ajustos.";
  [self.delegate panelModel:self didUpdateWithForce:YES changed:YES];
  [self.delegate panelModel:self needsConfiguration:self.configurationProblem];
}

- (NSDictionary *)visualSignature {
  return @{@"connected": @(self.connected), @"preview": @(self.preview), @"demo": @(self.demo),
           @"entities": self.entities ?: @[], @"live_updates": @(self.liveUpdates)};
}

- (void)refresh:(BOOL)force {
  if(!self.client) { return; }
  if(_loading) { _pendingUpdate = YES; _pendingForce = _pendingForce || force; return; }
  if(!self.authenticated && !self.preview) { [self session]; return; }
  NSDictionary *before = [self visualSignature];
  _loading = YES;
  NSUInteger generation = _clientGeneration;
  [self.client GET:@"/api/state" timeout:15 completion:^(NSString *error, id data, NSInteger status) {
    if(generation != self->_clientGeneration) { return; }
    self->_loading = NO;
    if(status == 401) { [self requireConfiguration:error]; return; }
    if(error) {
      self.connected = NO; self.error = error; self.fetchedAt = nil;
      if(force) { [self.delegate panelModel:self showToast:error]; }
    } else {
      self.connected = [data[@"connected"] isEqual:@YES];
      self.preview = [data[@"preview"] isEqual:@YES];
      self.demo = [data[@"demo"] isEqual:@YES];
      self.liveUpdates = [data[@"live_updates"] isEqual:@YES];
      self.fetchedAt = GRStr(data[@"fetched_at"]);
      self.error = GRStr(data[@"error"]);
      NSMutableArray *entities = [NSMutableArray array];
      for(id item in GRArray(data[@"entities"]) ?: @[]) { if(GRDict(item) && GRStr(item[@"entity_id"])) { [entities addObject:item]; } }
      self.entities = entities;
      [self checkActionConfirmation];
    }
    BOOL changed = force || ![before isEqual:[self visualSignature]];
    [self.delegate panelModel:self didUpdateWithForce:force changed:changed];
    [self schedulePoll];
    [self listenForUpdates];
    if(self->_pendingUpdate) {
      BOOL forceNext = self->_pendingForce;
      self->_pendingUpdate = NO; self->_pendingForce = NO;
      [self refresh:forceNext];
    }
  }];
}

- (void)schedulePoll {
  [_pollTimer cancel]; _pollTimer = nil;
  if(!_background && (self.authenticated || self.preview)) {
    __weak GRPanelModel *weakSelf = self;
    _pollTimer = [GRTimer after:GRPollInterval block:^{ [weakSelf refresh:NO]; }];
  }
}

#pragma mark - Live updates (server long-poll fed by the Home Assistant WebSocket)

- (void)stopUpdateListener {
  _updateGeneration++;
  [_updateRetryTimer cancel]; _updateRetryTimer = nil;
  [_updateTask cancel]; _updateTask = nil;
}

- (void)listenForUpdates {
  if(_updateTask || _background || !self.authenticated || self.preview || !self.client) { return; }
  NSUInteger generation = _updateGeneration;
  __weak GRPanelModel *weakSelf = self;
  NSString *path = [NSString stringWithFormat:@"/api/updates?since=%lld", _updateRevision];
  _updateTask = [self.client GET:path timeout:30 completion:^(NSString *error, id data, NSInteger status) {
    GRPanelModel *model = weakSelf;
    if(!model || generation != model->_updateGeneration) { return; }
    model->_updateTask = nil;
    if(status == 401) { [model requireConfiguration:error]; return; }
    if(error) { model->_updateRetryTimer = [GRTimer after:2 block:^{ [weakSelf listenForUpdates]; }]; return; }
    NSNumber *revision = GRNum(data[@"revision"]);
    if(revision && revision.longLongValue > model->_updateRevision) { model->_updateRevision = revision.longLongValue; [model refresh:NO]; }
    [model listenForUpdates];
  }];
}

#pragma mark - Commands

- (void)sendAction:(NSDictionary *)entity control:(NSDictionary *)control value:(id)value code:(NSString *)code
        completion:(void (^)(NSString *))completion {
  if(self.busy || !self.connected || self.preview || ![control[@"enabled"] isEqual:@YES]) {
    [self.delegate panelModel:self showToast:@"Aquest control encara no està disponible."];
    return;
  }
  self.busy = YES;
  NSMutableDictionary *payload = [@{@"entity_id": entity[@"entity_id"], @"action": control[@"action"]} mutableCopy];
  if(value) { payload[@"value"] = value; }
  if(code) { payload[@"code"] = code; }
  NSString *action = GRStr(control[@"action"]);
  NSString *entityId = GRStr(entity[@"entity_id"]);
  BOOL light = [GRStr(entity[@"domain"]) isEqualToString:@"light"] && ([action isEqualToString:@"turn_on"] || [action isEqualToString:@"turn_off"]);
  NSUInteger generation = _clientGeneration;
  [self.client POST:@"/api/action" body:payload timeout:15 completion:^(NSString *error, id data, NSInteger status) {
    if(generation != self->_clientGeneration) { return; }
    self.busy = NO;
    if(status == 401) { [self requireConfiguration:error]; return; }
    [self.delegate panelModel:self showToast:error];
    completion(error);
    [self refresh:YES];
    if(!error && light) { [self scheduleActionRefreshes:@[entityId] action:action]; }
  }];
  [payload removeObjectForKey:@"code"];
}

- (void)turnLights:(NSArray<NSDictionary *> *)lights place:(NSString *)place action:(NSString *)action skipped:(NSUInteger)skipped {
  if(self.busy || !self.connected || self.preview || !lights.count) { return; }
  NSMutableArray *ids = [NSMutableArray array];
  for(NSDictionary *light in lights) {
    if(![GRStr(light[@"status"]) isEqualToString:@"ok"]) { [self.delegate panelModel:self showToast:@"No es pot canviar l’estat: hi ha un llum no disponible."]; return; }
    if(![GRLogic entity:light hasEnabledAction:action]) { [self.delegate panelModel:self showToast:@"L’ordre per a algun llum encara no està verificada."]; return; }
    [ids addObject:light[@"entity_id"]];
  }
  self.busy = YES;
  [self.delegate panelModel:self showToast:[NSString stringWithFormat:@"Enviant %lu%@ a %@…", (unsigned long)lights.count, lights.count == 1 ? @" ordre" : @" ordres", place]];
  NSUInteger generation = _clientGeneration;
  [self.client POST:@"/api/lights" body:@{@"entity_ids": ids, @"action": action} timeout:60 completion:^(NSString *error, id data, NSInteger status) {
    if(generation != self->_clientGeneration) { return; }
    self.busy = NO;
    if(status == 401) { [self.delegate panelModel:self showToast:nil]; [self requireConfiguration:error]; return; }
    NSNumber *succeeded = GRNum(data[@"succeeded"]), *failed = GRNum(data[@"failed"]);
    if(error) { [self.delegate panelModel:self showToast:error]; }
    else if(![data[@"ok"] isEqual:@YES]) {
      [self.delegate panelModel:self showToast:[NSString stringWithFormat:@"Ordres enviades: %@. Sense enviar: %@. %@", succeeded ?: @0, failed ?: @0, GRStr(data[@"error"]) ?: @""]];
    } else if(skipped) {
      [self.delegate panelModel:self showToast:[NSString stringWithFormat:@"Ordres enviades: %@. Llums omesos: %lu (no disponibles o sense verificació).", succeeded ?: @0, (unsigned long)skipped]];
    } else { [self.delegate panelModel:self showToast:nil]; }
    [self refresh:YES];
    if(succeeded.integerValue > 0) { [self scheduleActionRefreshes:ids action:action]; }
  }];
}

- (void)clearActionRefreshes {
  for(GRTimer *timer in _actionRefreshTimers) { [timer cancel]; }
  [_actionRefreshTimers removeAllObjects];
  _pendingConfirmation = nil;
}

- (void)scheduleActionRefreshes:(NSArray *)ids action:(NSString *)action {
  [self clearActionRefreshes];
  _pendingConfirmation = @{@"ids": [ids copy], @"target": [action isEqualToString:@"turn_on"] ? @"on" : @"off"};
  __weak GRPanelModel *weakSelf = self;
  for(NSNumber *delay in @[@2, @5, @10, @20, @30]) {
    [_actionRefreshTimers addObject:[GRTimer after:delay.doubleValue block:^{
      GRPanelModel *model = weakSelf;
      if(model && model->_pendingConfirmation && !model->_background) { [model refresh:NO]; }
    }]];
  }
}

- (void)checkActionConfirmation {
  if(!_pendingConfirmation || !self.connected) { return; }
  for(NSString *entityId in _pendingConfirmation[@"ids"]) {
    BOOL found = NO;
    for(NSDictionary *entity in self.entities) {
      if([entity[@"entity_id"] isEqual:entityId] && [GRStr(entity[@"status"]) isEqualToString:@"ok"]
         && [GRStr(entity[@"state"]) isEqualToString:_pendingConfirmation[@"target"]]) { found = YES; break; }
    }
    if(!found) { return; }
  }
  [self clearActionRefreshes];
}

#pragma mark - Climate history

- (void)resetHistory {
  [_historyTask cancel]; _historyTask = nil; _historyGeneration++;
  self.historySeries = @{}; self.historyLoading = NO; self.historyError = nil; _historyLoadedAt = 0;
}

- (void)loadClimateHistory {
  NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
  if(!self.connected || !self.climateVisible || ![GRLogic entities:self.entities inCategory:@"climate"].count
     || self.historyLoading || now - _historyLoadedAt < 120) { return; }
  self.historyLoading = YES; self.historyError = nil;
  [self.delegate panelModelHistoryDidChange:self];
  NSUInteger generation = ++_historyGeneration;
  NSString *path = [NSString stringWithFormat:@"/api/climate-history?hours=%ld", (long)self.historyHours];
  _historyTask = [self.client GET:path timeout:15 completion:^(NSString *error, id data, NSInteger status) {
    if(generation != self->_historyGeneration) { return; }
    self->_historyTask = nil; self.historyLoading = NO; self->_historyLoadedAt = [NSDate timeIntervalSinceReferenceDate];
    if(status == 401) { [self requireConfiguration:error]; return; }
    if(error) { self.historyError = @"No s’ha pogut carregar l’historial."; }
    else { self.historySeries = [self parsedSeries:GRDict(data[@"series"])]; }
    if(self.climateVisible) { [self.delegate panelModelHistoryDidChange:self]; }
  }];
}

- (NSDictionary *)parsedSeries:(NSDictionary *)raw {
  NSMutableDictionary *series = [NSMutableDictionary dictionary];
  for(NSString *entityId in raw) {
    NSMutableArray *points = [NSMutableArray array];
    for(id point in GRArray(raw[entityId]) ?: @[]) {
      NSNumber *value = GRNum(GRDict(point)[@"value"]);
      NSString *time = GRStr(GRDict(point)[@"time"]);
      if(value && time) { [points addObject:@{@"time": time, @"value": value}]; }
    }
    series[entityId] = points;
  }
  return series;
}

- (void)changeClimatePeriod:(NSInteger)hours {
  [self resetHistory];
  self.historyHours = hours;
  [self.delegate panelModelHistoryDidChange:self];
}

#pragma mark - Audit

- (void)loadAudit:(void (^)(NSString *))completion {
  [self.client GET:@"/api/audit" timeout:15 completion:^(NSString *error, id data, NSInteger status) {
    if(error) { completion(error); return; }
    NSData *pretty = [NSJSONSerialization dataWithJSONObject:data options:NSJSONWritingPrettyPrinted error:NULL];
    NSString *text = pretty ? [[NSString alloc] initWithData:pretty encoding:NSUTF8StringEncoding] : @"";
    completion([text stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"]);
  }];
}

@end
