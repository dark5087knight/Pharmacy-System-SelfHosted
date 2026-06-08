#!/bin/bash

service postgresql start

sleep 5

cd /app/app
exec uvicorn app.main:app --host 0.0.0.0 --port 8000