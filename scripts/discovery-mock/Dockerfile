FROM python:3

ENV OKAPI 'https://folio-snapshot-okapi.dev.folio.org'
ENV USERNAME 'diku_admin'
ENV PASSWORD 'admin'
ENV TENANT 'diku'

COPY . .
RUN pip install -r requirements.txt

CMD [ "python", "./dummy.py" ]
