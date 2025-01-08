FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN apt update
RUN apt install -y libgl1-mesa-glx
RUN apt install -y libglib2.0-0
# 安装依赖
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV FLASK_APP=app.py
ENV FLASK_ENV=production

EXPOSE 5000

CMD ["flask", "run", "--host=0.0.0.0"]
