FROM ubuntu:16.04

WORKDIR /package

COPY . ./package



RUN swift package resolve 
CMD swift build