# 1. 공식 Python 이미지를 기반으로
FROM python:3.11

# 2. 컨테이너 작업 디렉토리 생성
WORKDIR /app

# 3. 소스 코드 복사
COPY requirements.txt ./
RUN pip install -r requirements.txt

COPY app.py ./

# 4. 5000포트 오픈
EXPOSE 5000

# 5. 실행 명령어
CMD ["python", "app.py"]
