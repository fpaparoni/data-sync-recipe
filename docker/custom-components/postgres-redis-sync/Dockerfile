FROM python:3.11-slim

WORKDIR /app

RUN pip install --no-cache-dir psycopg2-binary redis

COPY sync.py .

CMD ["python","-u","sync.py"]