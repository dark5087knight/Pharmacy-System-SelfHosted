FROM ubuntu

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y \
    python3 \
    python3-pip \
    postgresql \
    postgresql-contrib

WORKDIR /app

COPY ./Backend /app/app

COPY start.sh /app/start.sh

RUN pip3 install --break-system-packages -r app/requirements.txt

RUN service postgresql start && \
    until pg_isready -h localhost -U postgres; do sleep 1; done && \
    su - postgres -c "psql -c \"CREATE ROLE pharmacy WITH SUPERUSER LOGIN PASSWORD 'PassWD';\"" && \   
    su - postgres -c "psql -c \"CREATE ROLE pharmacy_app;\"" && \
    su - postgres -c "psql -c \"CREATE DATABASE pharmacy OWNER pharmacy;\"" && \
    cd /app/app && DATABASE_URL=postgresql+asyncpg://pharmacy:PassWD@127.0.0.1:5432/pharmacy python3 scripts/seed.py && \
    su - postgres -c "psql -d pharmacy -c \"GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO pharmacy_app;\"" && \
    su - postgres -c "psql -d pharmacy -c \"GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO pharmacy_app;\"" && \
    service postgresql stop

RUN chmod +x /app/start.sh

ENV DATABASE_URL=postgresql+asyncpg://pharmacy:PassWD@127.0.0.1:5432/pharmacy

EXPOSE 8000

CMD ["/app/start.sh"]