cli script /Common/verifyHash {\n
proc script::run {} {\n
        if {[catch {\n
            set hashes(f5-cloud-libs.tar.gz) 8103cc640a41ad327fe103463e262ba5f700df51f9b8304723b2cf33bfd5c80e4a1bb7869f7b466dddd6f6e9351286e0024c0b212d29dc55b849d15558f66369\n
            set hashes(f5-cloud-libs-aws.tar.gz) 6689f940fa4863dda289a16b73b64284efc5f88a7aad3e6f574d9928704ef587728765bbfc39454172cd9624f31096f5335432ec7eb3bff67aaf1313b5d6553d\n
            set hashes(f5-cloud-libs-azure.tar.gz) a4ff4a9af058ce6058159531fd7bca07eb8808cdd1b1e13de0e1324ec7e4692211991ecaa58dc36021c6c88c7783837d480584393753c3dfc2fddf623781e3a9\n
            set hashes(asm-policy-linux.tar.gz) 63b5c2a51ca09c43bd89af3773bbab87c71a6e7f6ad9410b229b4e0a1c483d46f1a9fff39d9944041b02ee9260724027414de592e99f4c2475415323e18a72e0\n
            set hashes(f5.http.v1.2.0rc4.tmpl) 47c19a83ebfc7bd1e9e9c35f3424945ef8694aa437eedd17b6a387788d4db1396fefe445199b497064d76967b0d50238154190ca0bd73941298fc257df4dc034\n
            set hashes(f5.http.v1.2.0rc6.tmpl) 811b14bffaab5ed0365f0106bb5ce5e4ec22385655ea3ac04de2a39bd9944f51e3714619dae7ca43662c956b5212228858f0592672a2579d4a87769186e2cbfe\n
            set hashes(f5.http.v1.2.0rc7.tmpl) 21f413342e9a7a281a0f0e1301e745aa86af21a697d2e6fdc21dd279734936631e92f34bf1c2d2504c201f56ccd75c5c13baa2fe7653213689ec3c9e27dff77d\n
            set hashes(f5.aws_advanced_ha.v1.3.0rc1.tmpl) 9e55149c010c1d395abdae3c3d2cb83ec13d31ed39424695e88680cf3ed5a013d626b326711d3d40ef2df46b72d414b4cb8e4f445ea0738dcbd25c4c843ac39d\n
            set hashes(f5.aws_advanced_ha.v1.4.0rc1.tmpl) de068455257412a949f1eadccaee8506347e04fd69bfb645001b76f200127668e4a06be2bbb94e10fefc215cfc3665b07945e6d733cbe1a4fa1b88e881590396\n
            set hashes(asm-policy.tar.gz) 2d39ec60d006d05d8a1567a1d8aae722419e8b062ad77d6d9a31652971e5e67bc4043d81671ba2a8b12dd229ea46d205144f75374ed4cae58cefa8f9ab6533e6\n
            set hashes(deploy_waf.sh) 4c125f7cbc4d701cf50f03de479ebe99a08c2b2c3fa6aae3e229eb3f0bba98bb513d630368229c98e7c5c907e6a3168ece2f8f576267514bad4f6730ea14d454\n
            set hashes(f5.policy_creator.tmpl) 54d265e0a573d3ae99864adf4e054b293644e48a54de1e19e8a6826aa32ab03bd04c7255fd9c980c3673e9cd326b0ced513665a91367add1866875e5ef3c4e3a\n
            set hashes(f5.service_discovery.tmpl) 40664fe0d8d822378256949e60167a06df0b1f36d6fda1a74d9e704728d48d281ccd703f779cae4b2d029cd2c690d7774fdc0bb29de9592bffabc51638c88ff1\n
            \n
            set file_path [lindex $tmsh::argv 1]\n
            set file_name [file tail $file_path]\n
            \n
            if {![info exists hashes($file_name)]} {\n
                tmsh::log err \"No hash found for $file_name\"\n
                exit 1\n
            }\n
            \n
            set expected_hash $hashes($file_name)\n
            set computed_hash [lindex [exec /usr/bin/openssl dgst -r -sha512 $file_path] 0]\n
            if { $expected_hash eq $computed_hash } {\n
                exit 0\n
            }\n
            tmsh::log err \"Hash does not match for $file_path\"\n
            exit 1\n
        }]} {\n
            tmsh::log err {Unexpected error in verifyHash}\n
            exit 1\n
        }\n
    }\n
    script-signature YMSDDRfh5B1TW+mZA8lacERGCa56OnIwUVaVNk5fPK0lSsIXmrM7+5YxErnxNrfAm/RZXwB4YmzafdAPD/UajXITuWxiOH5HLeFHeuXNc6MIT57YyB2nwW4gRhsI5ywI1p+L8N5wlZEn9PHIDRQg6Jwd5NaG8vBT2nvRzV6NBdsEeFnMl4MSW42evxdeRAu/HLDjJo4PgpsC0Wnm7NA0LQg8pm7vLLCKoMnCBTW9hCC2womHmup6uebp8XTRrsk/pA1f7zWHmXwOEdIGpqiXDXH7wSFvAcm+xQGPkJWF+vbJNFWbE0/PKoqu5eVE8gk3Vrgt8jV/wbmNFnbZ6635rg==\n
    signing-key /Common/f5-irule\n
}