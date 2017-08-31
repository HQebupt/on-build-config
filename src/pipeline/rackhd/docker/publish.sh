#!/bin/bash -e

#########################################
#
#  Usage
#
#########################################
Usage(){
    echo "function: this script is used to push rackhd docker images to docker hub"
    echo "usage: $0 [options] [arguments]"
    echo "    mandatory arguments:"
    echo "      --DOCKER_STASH_PATH: The directory path of docker images tar file."
    echo "      --DOCKERHUB_USER: the username of dockerhub"
    echo "      --DOCKERHUB_PASS: Password for DOCKERHUB_USER of dockerhub."
}

###################################################################
#
#  Parse and check Arguments
#
##################################################################
parseArguments(){
    while [ "$1" != "" ]; do
        case $1 in
            --DOCKER_STASH_PATH )           shift
                                            DOCKER_STASH_PATH=$1
                                            ;;
            --DOCKERHUB_USER )              shift
                                            DOCKERHUB_USER=$1
                                            ;;
            --DOCKERHUB_PASS )              shift
                                            DOCKERHUB_PASS=$1
                                            ;;
           * )
                                            Usage
                                            exit 1
        esac
        shift
    done
    if [ ! -n "${DOCKER_STASH_PATH}" ]; then
        echo "[Error]Arguments DOCKER_STASH_PATH is required"
        exit 1
    fi
    if [ ! -n "${DOCKERHUB_USER}" ]; then
        echo "[Error]Arguments DOCKERHUB_USER is required"
        exit 1
    fi
    if [ ! -n "${DOCKERHUB_PASS}" ]; then
        echo "[Error]Arguments DOCKERHUB_PASS is required"
        exit 1
    fi
}

# Clean UP. (was in Jenkins job post-build, avoid failure impacts build status.)
cleanUp(){
    # parameter : the images keyword to be delete
    keyword=$1
    images=`docker images | grep ${keyword} | awk '{print $3}' | sort | uniq`
    if [ -n "$images" ]; then
        docker rmi -f $images
    fi
}

cleanRunningContainers() {
    local containers=$(docker ps -a -q)
    if [ "$containers" != "" ]; then
        echo "Clean Up containers : " ${containers}
        docker stop ${containers}
        docker rm  ${containers}
    fi
}

loadImages() {
    echo "Load docker images and push."
    local tmp_build_record=$(mktemp)
    docker load -i $DOCKER_STASH_PATH | tee ${tmp_build_record}

    if [ $? -ne 0 ]; then
        echo "[ERROR] Docker load failed, aborted."
        exit -2
    fi

    docker login -u $DOCKERHUB_USER -p $DOCKERHUB_PASS

    local repo=""
    while IFS=: read -r load imagename tag
    do
        repo="${imagename}:${tag}"
        echo "Pushing ${repo}"
        docker push ${repo}
        if [ $? != 0 ]; then
            echo "Failed to push ${repo}"
            exit 1
        fi
    done < ${tmp_build_record}
    docker logout
    echo "docker logout."
}


cleanEnv() {
    set -x
    echo "Show local docker images"
    docker ps
    docker images
    echo "Stop & rm all docker running containers "
    cleanRunningContainers
    echo "Clean Up all docker images in local repo"
    cleanUp none
    # clean images by order, on-core should be last one because others depends on it
    cleanUp on-taskgraph
    cleanUp on-http
    cleanUp on-tftp
    cleanUp on-dhcp-proxy
    cleanUp on-syslog
    cleanUp on-tasks
    cleanUp files
    cleanUp isc-dhcp-server
    cleanUp on-wss
    cleanUp on-statsd
    cleanUp on-core
    cleanUp rackhd

    echo "clean up /var/lib/docker/volumes"
    docker volume ls -qf dangling=true | xargs -r docker volume rm
    set +x
}



########################################################
#
# Main
#
########################################################

main(){
    echo "docker publish start to parse arguments."
    parseArguments "$@"
    loadImages
    cleanEnv

    exit 0 # this is a workaround. to avoid the cleanup failure makes whole workflow fail.don't worry, the set -e will ensure failure captured for necessary steps(those lines before set +e)
}

main "$@"
