#!/bin/bash

# -------------------------------------------------------------------------- #
# Copyright 2002-2022, OpenNebula Project, OpenNebula Systems                #
#                                                                            #
# Licensed under the Apache License, Version 2.0 (the "License"); you may    #
# not use this file except in compliance with the License. You may obtain    #
# a copy of the License at                                                   #
#                                                                            #
# http://www.apache.org/licenses/LICENSE-2.0                                 #
#                                                                            #
# Unless required by applicable law or agreed to in writing, software        #
# distributed under the License is distributed on an "AS IS" BASIS,          #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   #
# See the License for the specific language governing permissions and        #
# limitations under the License.                                             #
#--------------------------------------------------------------------------- #

#-------------------------------------------------------------------------------
# DIR DEFINITIONS
#  - SRC dir to build the tests
#  - LIB dir to install aux libraries
# LIBRARIES
#  - OCA_JAR OpenNebula JAR libs
#  - JUNIT_URL to download JUNIT lib
#  - HAMCREST_URL fo download HAMCREST lib
#-------------------------------------------------------------------------------
SRC_DIR="./src"
LIB_DIR="./lib"

OCA_JAR="/usr/share/java/org.opennebula.client.jar"
JUNIT_URL="http://search.maven.org/remotecontent?filepath=junit/junit/4.12/junit-4.12.jar"
HAMCREST_URL="http://search.maven.org/remotecontent?filepath=org/hamcrest/hamcrest-core/1.3/hamcrest-core-1.3.jar"
#-------------------------------------------------------------------------------
# BUILD FUNCTIONS
#-------------------------------------------------------------------------------

do_junit_install()
{
    cd $LIB_DIR
    curl -LO $JUNIT_URL
    curl -LO $HAMCREST_URL
    cd -
}

do_tests()
{
    echo "Compiling OpenNebula Cloud API Tests..."
    javac -d $SRC_DIR -classpath $OCA_JAR:$LIB_DIR/* `find $SRC_DIR -name *.java`
}

#do_junit_install

do_tests

