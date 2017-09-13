package pipeline.common.release

def submodule(String operation, String library_dir, String tag_name, String manifest_path, String target_dir) {
        def retry_times = 3

        withCredentials([
            //usernameColonPassword(credentialsId: 'GITHUB_USER_PASSWORD_OF_JENKINSRHD',
            usernameColonPassword(credentialsId: 'JENKINSRHD_GITHUB_CREDS_QIANG',
                                  variable: 'JENKINSRHD_GITHUB_CREDS'),
            usernamePassword(credentialsId: 'a94afe79-82f5-495a-877c-183567c51e0b',
                             passwordVariable: 'BINTRAY_API_KEY',
                             usernameVariable: 'BINTRAY_USERNAME')]){
            retry(retry_times){
                timeout(5){
                    sh """#!/bin/bash -ex
                    # Update the submodule according to the manifest file.
                    pushd $library_dir
                    ./build-release-tools/HWIMO-BUILD build-release-tools/application/${operation}_submodule.py \
                    --manifest $manifest_path \
                    --build-dir $target_dir \
                    --publish \
                    --version ${tag_name} \
                    --git-credential https://github.com/hqebupt,JENKINSRHD_GITHUB_CREDS
                    popd
                    """
                }
            }
        }
}
