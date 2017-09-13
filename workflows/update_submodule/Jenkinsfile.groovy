@Library('my_library') _
node{
    timestamps{
        withEnv([
            "tag_name=${env.tag_name}",
            "branch=${env.branch}",
            "date=current",
            "timezone=-0500",
            "IS_OFFICIAL_RELEASE=true",
            "TAG=${env.TAG}",
            "JUMP_VERSION=${env.JUMP_VERSION}",
            "PUBLISH=${env.PUBLISH}",
            "TESTS=${env.TESTS}",
            "OVA_POST_TESTS=${env.OVA_POST_TESTS}",
            //"HTTP_STATIC_FILES=${env.HTTP_STATIC_FILES}",
            //"TFTP_STATIC_FILES=${env.TFTP_STATIC_FILES}",
            "USE_VCOMPUTE=${env.USE_VCOMPUTE}",
            "OS_VER=${env.OS_VER}",
            "BINTRAY_SUBJECT=${env.BINTRAY_SUBJECT}",
            "BINTRAY_REPO=binary"])
        {
            def message = "Job Name: ${env.JOB_NAME} \n" + "Build Full URL: ${env.BUILD_URL} \n" + "Phase: STARTED \n"
            echo "$message"
            slackSend "$message"
            deleteDir()

            def manifest = new pipeline.common.Manifest()
            def share_method = new pipeline.common.ShareMethod()
            String library_dir = "on-build-config"
            String target_dir = "$WORKSPACE/b"
            String manifest_path = "$WORKSPACE/on-build-config/workflows/update_submodule/rackhd_manifest"
            share_method.checkoutOnBuildConfig(library_dir)
            //if("${env.MANIFEST_FILE_URL}" == "null" || "${env.MANIFEST_FILE_URL}" == ""){
            //    stage("Generate Manifest"){
            //        manifest_path = manifest.generateManifestFromGithub(target_dir, library_dir)
            //    }
            //} else{
            //    manifest_path = manifest.downloadManifest(MANIFEST_FILE_URL, "$WORKSPACE")
            manifest.checkoutAccordingToManifest(manifest_path, target_dir, library_dir)
            //}

            def submodule = new pipeline.common.release.UpdateSubmodule()
            Boolean should_revert_submodule= false

            def dest_manifest = "$WORKSPACE/${tag_name}"
            try{
                stage("Check JIRA"){
                  //  load("jobs/SprintRelease/check_jira.groovy")
                }

                if(JUMP_VERSION == "true"){
                    //load("jobs/SprintRelease/bump_version.groovy")
                }

                stage("update submodule"){
                    submodule.submodule("update", library_dir, tag_name, manifest_path, target_dir)
                    should_revert_submodule = true // init value
                }

                stage("Update Manifest"){
                    manifest.generateManifestFromLocalRepos(target_dir, dest_manifest, library_dir)
                    def updated_manifest_url = manifest.publishManifest(dest_manifest, library_dir)
                    env.MANIFEST_FILE_URL = updated_manifest_url
                    echo "[DEBUG] updated manifest file url:${updated_manifest_url}"
                }

                def manifest_name=env.MANIFEST_FILE_URL.tokenize('/')[-1]
                currentBuild.description = "<a href=${env.MANIFEST_FILE_URL}>${manifest_name}</a>"

                stash name: "sprint_release_manifest", includes: "${dest_manifest}"
                env.stash_manifest_name = "sprint_release_manifest"
                env.stash_manifest_path = "${dest_manifest}"

                def repo_dir = pwd()
                def TESTS = "${env.TESTS}"
                def test_type = "manifest"
                // Create an instance of UnitTest/UnitTest.groovy   
                def unit_test = load("jobs/UnitTest/UnitTest.groovy")
                // Create an instance of FunctionTest/FunctionTest.groovy
                //def function_test = load("jobs/FunctionTest/FunctionTest.groovy")
                //def source_based_test = load("jobs/FunctionTest/SourceBasedTest.groovy")
                try{
                    stage("Unit Test"){
                        // Call the function runTest to run unit test
                        unit_test.runTest(env.stash_manifest_name, env.stash_manifest_path, repo_dir)
                    }
                    stage("Function Test"){
                        // Run function test
                        //source_based_test.runTests(function_test)
                    }
                }finally{
                    //unit_test.archiveArtifactsToTarget("UnitTest")
                    //source_based_test.archiveArtifacts(function_test)
                }
                Boolean create_tag = TAG.toBoolean()
                Boolean publish = PUBLISH.toBoolean()
                // share_method.buildAndPublish(publish, create_tag, repo_dir)
                currentBuild.result="SUCCESS"
                should_revert_submodule = false ; // all test pass, no need to revert submodule update
            } finally{
                if( should_revert_submodule ){
                    stage("revert submodule"){
                        submodule.submodule("revert", library_dir, tag_name, dest_manifest, target_dir)
                    }
                    stage("Update Manifest"){
                        manifest.generateManifestFromLocalRepos(target_dir, dest_manifest, library_dir)
                        def updated_manifest_url = manifest.publishManifest(dest_manifest, library_dir)
                        echo "[DEBUG] updated manifest file url:${updated_manifest_url}"
                    }

                }
                share_method.sendResultToSlack()
                share_method.sendResultToMysql(true, true)
            }
        }
    }
}
