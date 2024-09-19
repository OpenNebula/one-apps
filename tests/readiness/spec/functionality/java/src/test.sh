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

# Usage: test.sh <Test_name>
# For instance: test.sh ImageTest


if [ -z $ONE_LOCATION ]; then
    LOG_LOCATION="/var/log/one"
else
    LOG_LOCATION="$ONE_LOCATION/var"
fi

JAR_LOCATION="/usr/share/java/org.opennebula.client.jar"

echo 'SAFE_DIRS = "/"' > /tmp/one-javatest-ds.txt
onedatastore update --append 1 /tmp/one-javatest-ds.txt

java -cp /usr/share/java/*:../lib/*:$JAR_LOCATION:. org.junit.runner.JUnitCore $1

CODE=$?

exit $CODE
