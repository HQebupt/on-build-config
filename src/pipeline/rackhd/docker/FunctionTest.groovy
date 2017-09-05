package pipeline.rackhd.docker

def keepEnv(String library_dir, boolean keep_env, int keep_minutes, String test_target, String test_name){
    try{
        if(keep_env){
            def message = "Job Name: ${env.JOB_NAME} \n" + "Build Full URL: ${env.BUILD_URL} \n" + "Status: FAILURE \n" + "Stage: $test_target/$test_name \n" + "Node Name: $NODE_NAME \n" + "Reserve Duration: $keep_minutes minutes \n"
            echo "$message"
            slackSend "$message"
            sleep time: keep_minutes, unit: 'MINUTES'
        }
    } catch(error){
        echo "[WARNING]: Failed to keep environment on failure with error: $error"
    }
}

/*
* Run rackhd funciton test based docker build & deploy.
* input:
* - stack_type: choose suited stack setting,such as "virtual_stack"
* - test_name: test type, such as "FIT" "OS_INSTALL"
* - used_resources: where the test will run
* - manifest_dict: where MANIFEST stash
* - docker_build_ret_dict: where docker tar file stash
* - rackhd_cred_dict: credential of rackhd
* - keep_env_on_failure: whether keep the running environment when failure occurs.
* - keep_minutes: time to keep the running environment.
*
*/
def runTest(String stack_type, String test_name, ArrayList<String> used_resources, Map manifest_dict, Map docker_build_ret_dict, Map rackhd_cred_dict, boolean keep_env_on_failure, int keep_minutes){
    def share_method = new pipeline.common.ShareMethod()
    String test_target = "docker"
    def fit_configure = new pipeline.fit.FitConfigure(stack_type, test_target, test_name)
    def fit_init_configure = new pipeline.fit.FitConfigure(stack_type, test_target, "INIT")

    fit_configure.configure()
    fit_init_configure.configure()
    String node_name = ""
    String label_name = fit_configure.getLabel()
    try{
        lock(label:label_name,quantity:1){
            node_name = share_method.occupyAvailableLockedResource(label_name, used_resources)
            echo "[DEBUG]node_name:${node_name}"
            node(node_name){
                deleteDir()
                def manifest = new pipeline.common.Manifest()
                def fit = new pipeline.fit.FIT()
                def virtual_node = new pipeline.nodes.VirtualNode()
                def rackhd_deployer = new pipeline.rackhd.docker.Deploy()
                String manifest_path = manifest.unstashManifest(manifest_dict, "$WORKSPACE")
                String library_dir = "$WORKSPACE/on-build-config"
                String rackhd_dir = "$WORKSPACE/RackHD"
                share_method.checkoutOnBuildConfig(library_dir)
                manifest.checkoutTargetRepo(manifest_path, "RackHD", rackhd_dir, library_dir)
                boolean ignore_failure = false
                String target_dir = test_target + "/" + test_name + "[$NODE_NAME]"
                String log_dir =" $WORKSPACE" + "/" + target_dir
                echo "rackhd_dir:${rackhd_dir}"
                echo "target_dir:${target_dir}"

                try{
                    // clean up rackhd and virtual nodes
                    rackhd_deployer.cleanUp(library_dir, rackhd_dir, ignore_failure)
                    echo "[DEBUG]rackhd_deployer cleanUp done."
                    virtual_node.cleanUp(library_dir, ignore_failure)
                    echo "[DEBUG]virtual_node cleanUp done."
                    virtual_node.stopFetchLogs(library_dir, target_dir)
                    echo "[DEBUG]virutal_node stopFetch done."

                    // deploy rackhd and virtual nodes
                    String docker_build_unstash_name = docker_build_ret_dict["DOCKER_STASH_NAME"]
                    unstash docker_build_unstash_name

                    String docker_tar_file   = "$WORKSPACE" + "/" + docker_build_ret_dict["DOCKER_STASH_PATH"]
                    rackhd_deployer.deploy(library_dir, log_dir, rackhd_dir, docker_tar_file)
                    echo "[DEBUG]rackhd_deployer.deploy done."
                    virtual_node.deploy(library_dir)
                    echo "[DEBUG]virtual_node deploy done."
                    virtual_node.startFetchLogs(library_dir, target_dir)
                    echo "[DEBUG]virtual_node startFetchLogs done."
                    // run FIT test
                    fit.configControlInterfaceIp(rackhd_dir)
                    echo "[DEBUG]fit configControlInterfaceIp done."
                    fit.configRackHDCredential(rackhd_dir, rackhd_cred_dict)
                    echo "[DEBUG]fit configRackHDCredential done"
                    fit.run(rackhd_dir, fit_init_configure)
                    echo "[DEBUG]fit run(rackhd_dir, fit_init_configure) done."
                    fit.run(rackhd_dir, fit_configure)
                    echo "[DEBUG]fit run(rackhd_dir, fit_configure) done."
                } catch(run_error){
                    keepEnv(library_dir, keep_env_on_failure, keep_minutes, test_target, test_name)
                    error("[ERROR] Failed to run test $test_name against $test_target with error: $run_error")
                } finally{
                    // archive rackhd logs
                    echo "[DEBUG]archive rackhd logs start."
                    rackhd_deployer.archiveLogsToTarget(library_dir, target_dir)
                    echo "[DEBUG]archive rackhd logs done."
                    fit.archiveLogsToTarget(target_dir, fit_configure)
                    echo "[DEBUG]fit archiveLogsToTarget done."
                    virtual_node.stopFetchLogs(library_dir, target_dir)
                    echo "[DEBUG]virtual_node stopFetchLogs done."
                    virtual_node.archiveLogsToTarget(target_dir)
                    echo "[DEBUG]virtual_node archiveLogsToTarget done."

                    // clean up rackhd and virtual nodes
                    ignore_failure = true
                    rackhd_deployer.cleanUp(library_dir, rackhd_dir, ignore_failure)
                    echo "[DEBUG]rackhd_deployer cleanUp done."
                    virtual_node.cleanUp(library_dir, ignore_failure)
                    echo "[DEBUG]virtual_node cleanUp done."
                }
            }
         }
    } finally{
         used_resources.remove(node_name)
         echo "[DEBUG]used_resources remove done."
    }
}

return this


