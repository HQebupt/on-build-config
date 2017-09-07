#!/bin/bash -e

##########################################
#
#  Usage
#
##########################################
Usage(){
    echo "Function:The script is to build the base docker image for CI test: "
    echo "a RackHD runtime env, will include RackHD dependency 3rd party lib/tools and run in a single Docker."
    echo "usage: $0 [arguments]"
    echo "    Optional Arguments:"
    echo "      --DOCKER_FOLDER: The directory path of the DockerFile."
    echo "      --TARGET_PATH: The directory path of the rackhd_pipeline_docker.tar file saved."
    echo "      --IMAGE_NAME: the name of the docker image."
    echo "    mandatory arguments:"
    echo "      --USER: the user owns the docker tar file."
    echo "      --SUDO_PASSWORD:Password of current user which has sudo privilege, it's required."
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
            --DOCKER_FOLDER )               shift
                                            DOCKER_FOLDER=$1
                                            ;;
            --USER )                        shift
                                            USER=$1
                                            ;;
            --SUDO_PASSWORD )               shift
                                            SUDO_PASSWORD=$1
                                            ;;
            --DOCKERHUB_USER )              shift
                                            DOCKERHUB_USER=$1
                                            ;;
            --DOCKERHUB_PASS )              shift
                                            DOCKERHUB_PASS=$1
                                            ;;
            --TARGET_PATH )                 shift
                                            TARGET_PATH=$1
                                            ;;
            --IMAGE_NAME )                  shift
                                            IMAGE_NAME=$1
                                            ;;
            * )
                                            Usage
                                            exit 1
        esac
        shift
    done
    if [ ! -n "${DOCKER_FOLDER}" ]; then
        DOCKER_FOLDER='.'
        echo "[NOTE] it's assumed that DockerFile's path is the current path: '.'"
    fi
    if [ ! -n "${USER}" ]; then
        echo "[Error]Arguments USER is required"
        exit 1
    fi
    if [ ! -n "${SUDO_PASSWORD}" ]; then
        echo "[Error]Arguments SUDO_PASSWORD is required"
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
    if [ ! -n "${TARGET_PATH}" ]; then
        TARGET_PATH='.'
        echo "[NOTE] it's assumed that the tar file saved in the current path: '.'"
    fi
    if [ ! -n "${IMAGE_NAME}" ]; then
        IMAGE_NAME='rackhd/pipeline'
        echo "[NOTE] use the default image name: ${IMAGE_NAME}"
    fi
}

buildAndPublish() {
	echo $SUDO_PASSWORD |sudo -S docker build -t $IMAGE_NAME $DOCKER_FOLDER
	echo $SUDO_PASSWORD |sudo -S docker login -u $DOCKERHUB_USER -p $DOCKERHUB_PASS
    set +e
	#echo $SUDO_PASSWORD |sudo -S docker push ${IMAGE_NAME}:latest
    set -e
	echo $SUDO_PASSWORD |sudo -S docker logout
}

saveImage() {
	local tar_file="${TARGET_PATH}/rackhd_pipeline_docker.tar"
	echo $SUDO_PASSWORD |sudo -S docker save -o $tar_file $IMAGE_NAME
	echo $SUDO_PASSWORD |sudo -S chown $USER:$USER $tar_file
}

########################################################
#
# Main
#
########################################################

main(){
    echo "Start to parse arguments."
    parseArguments "$@"

    echo "Build base docker image and publish."
    buildAndPublish

    echo "Save base docker image to ${TARGET_PATH}"
    saveImage

    echo "Main done."
}

main "$@"
