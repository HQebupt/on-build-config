package pipeline.rackhd.docker

def build(Map manifest_dict, String artifactory_url, String stage_repo_name){
    def ret_dict=[:]
    node(build_docker_node){
            deleteDir()
            def manifest = new pipeline.common.Manifest()
            String manifest_path = manifest.unstashManifest(manifest_dict, "$WORKSPACE")

            String library_dir = "$WORKSPACE/on-build-config"
            def share_method = new pipeline.common.ShareMethod()
            share_method.checkoutOnBuildConfig(library_dir)
            withCredentials([
                usernamePassword(credentialsId: 'ff7ab8d2-e678-41ef-a46b-dd0e780030e1',
                                 passwordVariable: 'SUDO_PASSWORD',
                                 usernameVariable: 'SUDO_USER')]){
                    timeout(90){
                        sh """#!/bin/bash -ex
                        bash $library_dir/src/pipeline/rackhd/docker/build.sh \
                               --MANIFEST_FILE  ${manifest_path} \
                               --ARTIFACTORY_URL ${artifactory_url} \
                               --STAGE_REPO_NAME ${stage_repo_name} \
                               --WORKDIR ${WORKSPACE}
                        """
                    }
                    archiveArtifacts 'rackhd_docker_images.tar'
                    stash name: 'docker', includes: 'rackhd_docker_images.tar'
                    env.DOCKER_STASH_NAME="docker"
                    env.DOCKER_STASH_PATH="rackhd_docker_images.tar"
                    ret_dict["DOCKER_STASH_NAME"]="docker"
                    ret_dict["DOCKER_STASH_PATH"]="rackhd_docker_images.tar"
            }
    }
    return ret_dict;
}
return this

