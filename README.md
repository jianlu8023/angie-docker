# angie-docker

## build image

* tongsuo ntls template image

```shell
docker buildx build -t angie:ntls-template-alpine -f Dockerfile-template .
```

* tonsuo ntls image

```shell
docker buildx build -t angie:ntls-alpine -f Dockerfile .
```
