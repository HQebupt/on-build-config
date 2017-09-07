#!/bin/bash -x

##########################################
#
#  Usage
#
##########################################
Usage(){
    echo "Function:The script is to build the base docker image for CI test: "
    echo "a RackHD runtime env, will include RackHD src code and run in a single Docker."
    echo "usage: $0 [arguments]"
    echo "    Optional Arguments:"
    echo "      --DOCKERFILE_PATH: The directory path of the DockerFile."
    echo "      --TARGET_PATH: The directory path of the rackhd_pipeline_docker.tar file saved."
    echo "    mandatory arguments:"
    echo "      --USER: the user owned the docker tar file."
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
            --DOCKERFILE_PATH )             shift
                                            DOCKERFILE_PATH=$1
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
            --DOCKERHUB_PASS )            shift
                                            DOCKERHUB_PASS=$1
                                            ;;
            --TARGET_PATH )                 shift
                                            TARGET_PATH=$1
                                            ;;
            * )
                                            Usage
                                            exit 1
        esac
        shift
    done
    if [ ! -n "${DOCKERFILE_PATH}" ]; then
        DOCKERFILE_PATH='.'
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
}

buildAndPublish() {
	echo $SUDO_PASSWORD |sudo -S docker build -t rackhd/pipeline $DOCKERFILE_PATH
	echo $SUDO_PASSWORD |sudo -S docker login -u $DOCKERHUB_USER -p $DOCKERHUB_PASS
	echo $SUDO_PASSWORD |sudo -S docker push rackhd/pipeline:latest
	echo $SUDO_PASSWORD |sudo -S docker logout
}

saveImage() {
	local tar_file="${TARGET_PATH}/rackhd_pipeline_docker.tar"
	echo $SUDO_PASSWORD |sudo -S docker save -o $tar_file rackhd/pipeline
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
