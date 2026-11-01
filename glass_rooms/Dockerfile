FROM python:3.13-alpine
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
RUN pip install --no-cache-dir websockets==15.0.1
COPY server.py catalog.py /app/
COPY www /app/www
EXPOSE 8099
CMD ["python3", "/app/server.py"]
