# Instruccions del projecte

## Publicacions a `main`

- Abans de cada push que publiqui commits nous a `origin/main`, incrementa la versió de l'aplicació a `glass_rooms/config.yaml`. Per a canvis compatibles, incrementa el component *patch* (`1.0.12` → `1.0.13`); per a canvis incompatibles, tria el component adequat i documenta la migració.
- Inclou el canvi de versió en el mateix commit o conjunt de commits que enviaràs. Comprova que la versió resultant és superior a la que hi ha a `origin/main` després de fer `git fetch`.
- Mantén coherent el número de revisió actual del `README.md` amb `glass_rooms/config.yaml` (l'app per a iPad i el seu `Info.plist` la llegeixen d'aquí en compilar). Conserva els números de versió que descriuen fets històrics.
- No afegeixis una versió a `breaking_versions` només per publicar una actualització; aquesta llista és per a canvis que requereixen una migració de configuració.
- Executa les proves aplicables i comprova `git diff --check` abans del push. Després, verifica que `main` i `origin/main` coincideixen i que no resten canvis pendents.
