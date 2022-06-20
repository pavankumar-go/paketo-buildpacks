### Build OCI specification containers using buildpacks by paketo.io and without Docker Daemon on GitLab CI
1. does not require docker inside build pods/containers
2. eleminates mounting underlying hosts docker socket `/var/run/docker.sock` (DIND in k8s: Big No No)
3. runs as non-root (unprivileged)

### But Why ?
Dockerfile is the oldest and most common approach for building images. basically a script containing docker instructions that creates a layer in a Docker image and upon executing final instruction the docker image is built. Requires creation and maintenance of Dockerfile on your own.

Buildpacks, A CNCF project (aka CNB) which doesn't require Dockerfile for building containers which eleminates creation/maintenance of the scripts. Just use the OSS buildpacks (or create one) which out-of-the-box provides the well-formed dockerfile functionalities & consists of base requirements for compiling an application.

Caveats:
1. OSS buildpacks are huge 
```
paketobuildpacks/builder:base    966MB
paketobuildpacks/builder:tiny    585MB
```
2. Build time is high (2x) when compared with `docker build or kaniko-executor`

### So How ?
##### For building maven applications using paketo's tiny buildpacks
the folder `buildpack-java` contains a Dockerfile, mainly for providing user defined environment variables required during build time, unfortunatley passing environment variables via args isn't supported in **Creator** a Platform Lifecycle Interface  https://github.com/buildpacks/spec/blob/main/platform.md#user-provided-variables

example: a buildtime environment variable in docker is passed as `--env APP=test` 
when using **creator** : a file with variable name is place under `/platform/env/APP` which contains a value test 
```
$ cat /platform/env/APP
test
```
`/buildpack-java/env` folder contains the environment variables for specifying the Java version & Maven arguments

Building the buildingpack with user-defined environment variables
```
docker build -t <TAG> . && docker push <TAG>
OR
buildah build --format=docker -f /buildpack-java/Dockerfile -t <TAG> .
```

###### Once the buildpack is built with user-defined environment variables, use it as a base image in your .gitlab-ci.yml stages

Pre-requisites:
1. add the following folder & file in your code root directory which specifies the maven version to be used 
```
$ mkdir -p .mvn/wrapper
$ echo 'distributionUrl=https://repo.maven.apache.org/maven2/org/apache/maven/apache-maven/3.6.3/apache-maven-3.6.3-bin.zip' > .mvn/wrapper/maven-wrapper.properties
```

```
build:
  interruptible: true
  image: myrepo/java-buildpack:tiny -> replace with the buildpack that was built  
  stage: build
  only:
    - main
    - merge_requests
  before_script:
    - mkdir ~/.docker
    - echo '{"credsStore":"ecr-login"}' > ~/.docker/config.json # works only on EKS with IRSA
    **OR** 
    - echo '{"auths":{"$CI_REGISTRY":{"username":"$CI_REGISTRY_USER","password":"$CI_JOB_TOKEN"}}}' >> ~/.docker/config.json
  script:
    - /cnb/lifecycle/creator -app . ${DOCKER_REGISTRY}/${APP_NAME}:${CI_PIPELINE_IID}
```
