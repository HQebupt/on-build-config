package pipeline.rackhd.docker

/*
publish rackhd
:library_dir: the directory of on-build-config
:docker_tar_path: where the docker image tar lies
:dockerhub_user: the rackhd user of dockerhub
:dockerhub_pass: the rackhd user password of dockerhub
*/
def publish(String library_dir, String docker_tar_path, String dockerhub_user, String dockerhub_pass) {
        timeout(120){
        	sh """#!/bin/bash -ex
        	pushd $library_dir/src/pipeline/rackhd/docker
        	./publish.sh --DOCKER_STASH_PATH $docker_tar_path \
        	--DOCKERHUB_USER $dockerhub_user \
        	--DOCKERHUB_PASS $dockerhub_pass
        	popd
        	"""
        }
}


/*
Example Usage:
node(build_docker_node){
    dir("on-build-config"){
        checkout scm
    }
    dir("DOCKER"){
        unstash env.DOCKER_STASH_NAME
    }
    String library_dir="on-build-config"


	ret_dict["DOCKER_STASH_NAME"]="docker"
	ret_dict["DOCKER_STASH_PATH"]="rackhd_docker_images.tar"

	String docker_tar_path= "$WORKSPACE" + "/DOCKER/" + ret_dict["DOCKER_STASH_PATH"]

    def docker_publisher = new pipeline.rackhd.docker.Publish()
    withCredentials([
        usernamePassword(credentialsId: 'rackhd-ci-docker-hub',
                         passwordVariable: 'DOCKERHUB_PASS',
                         usernameVariable: 'DOCKERHUB_USER')]) {
        retry(3) {
			docker_publisher.publish(library_dir, docker_tar_path,env.DOCKERHUB_USER, env.DOCKERHUB_PASS)
        }
    }
}
*/
