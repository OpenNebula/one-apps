// Copyright 2002-2025, OpenNebula Project, OpenNebula Systems
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// Portions of this file are derived from NVIDIA sample code:
// Copyright (c) 2025 NVIDIA CORPORATION. All rights reserved.
// Used under the terms of the NVIDIA Sample Source Code License.

#include <iostream>
#include <string>
#include <cstring>
#include <iomanip>
#include <limits>
#include <sstream>
#include <vector>
#include <fstream>
#include <algorithm>

#include "nv_fm_agent.h" 

const char* STATE_FILE_PATH = "/var/lib/nvidia-fabricmanager/active_partitions.state";

// --- State Management Functions ---

std::vector<fmFabricPartitionId_t> readState() {
    std::vector<fmFabricPartitionId_t> activePartitions;
    std::ifstream stateFile(STATE_FILE_PATH);
    fmFabricPartitionId_t id;
    while (stateFile >> id) {
        activePartitions.push_back(id);
    }
    return activePartitions;
}

void writeState(const std::vector<fmFabricPartitionId_t>& activePartitions) {
    std::ofstream stateFile(STATE_FILE_PATH, std::ios::trunc);
    for (const auto& id : activePartitions) {
        stateFile << id << std::endl;
    }
}

void updateStateFile(fmFabricPartitionId_t partitionId, bool activate) {
    auto activePartitions = readState();
    auto it = std::find(activePartitions.begin(), activePartitions.end(), partitionId);

    if (activate) {
        if (it == activePartitions.end()) {
            activePartitions.push_back(partitionId);
        }
    } else {
        if (it != activePartitions.end()) {
            activePartitions.erase(it);
        }
    }
    writeState(activePartitions);
}


void printFmError(const char* operation, fmReturn_t fmReturn) {
    std::cout << "Error: Failed to " << operation << ". (Code: " << fmReturn << ")" << std::endl;
}

void clearCin() {
    std::cin.clear();
    std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
}

void printMenu() {
    std::cout << "------------------------------------------\n";
    std::cout << "Fabric Manager Partition Operations:\n";
    std::cout << "  0 - List Supported Partitions\n";
    std::cout << "  1 - Activate a Partition\n";
    std::cout << "  2 - Deactivate a Partition\n";
    std::cout << "  3 - Restore Active Partitions\n";
    std::cout << "  4 - Quit\n";
    std::cout << "------------------------------------------\n";
    std::cout << "Enter operation: ";
}

fmReturn_t executeOperation(fmHandle_t fmHandle, unsigned int operation, fmFabricPartitionId_t partitionId, const std::string& outputFormat)
{
    fmReturn_t fmReturn = FM_ST_SUCCESS;
    fmFabricPartitionList_t partitionList = {0};
    
    const fmFabricPartitionId_t PARTITION_ID_NOT_SET = 9999; 

    switch (operation) {
        case 0: { // List Supported Partitions
            partitionList.version = fmFabricPartitionList_version;
            fmReturn = fmGetSupportedFabricPartitions(fmHandle, &partitionList);
            
            if (fmReturn != FM_ST_SUCCESS) {
                printFmError("get partition list", fmReturn);
            } else {
                
                // CSV or Table
                if (outputFormat == "csv") {
                    
                    // CSV HEADER
                    std::cout << "Partition_ID,Num_GPUs,GPU_Module_IDs,Max_NVLinks_per_GPU,Status" << std::endl;
                    
                    for (unsigned int i = 0; i < partitionList.numPartitions; ++i) {
                        const auto& info = partitionList.partitionInfo[i];
                        
                        std::stringstream gpu_list_ss;
                        unsigned int max_nvlinks = 0; 
                        bool first_gpu = true;
                        
                        for (unsigned int j = 0; j < info.numGpus; ++j) {
                            if (!first_gpu) gpu_list_ss << " "; // Use space separator in CSV column
                            gpu_list_ss << info.gpuInfo[j].physicalId;
                            if (j == 0) max_nvlinks = info.gpuInfo[j].maxNumNvLinks; 
                            first_gpu = false;
                        }

                        std::string gpu_list = gpu_list_ss.str();
                        if (gpu_list.empty()) gpu_list = "N/A";

                        // CSV Row Output
                        std::cout << info.partitionId << ","
                                  << info.numGpus << ","
                                  << "\"" << gpu_list << "\","
                                  << max_nvlinks << ","
                                  << (info.isActive ? "ACTIVE" : "INACTIVE") 
                                  << std::endl;
                    }

                } else { 
                    // Def --> Table Output
                    
                    std::cout << "Total supported partitions: " << partitionList.numPartitions << "\n" << std::endl;
                    
                    std::cout << std::left << std::setw(15) << "Partition ID"
                              << std::left << std::setw(15) << "Number of GPUs"
                              << std::left << std::setw(25) << "GPU Module ID"
                              << std::left << std::setw(20) << "Max NVLinks/GPU"
                              << std::left << "STATUS" << std::endl;
                    std::cout << "--------------------------------------------------------------------------------" << std::endl;
                    
                    for (unsigned int i = 0; i < partitionList.numPartitions; ++i) {
                        const auto& info = partitionList.partitionInfo[i];
                        
                        std::stringstream gpu_list_ss;
                        unsigned int max_nvlinks = 0; 
                        bool first_gpu = true;
                        
                        for (unsigned int j = 0; j < info.numGpus; ++j) {
                            if (!first_gpu) gpu_list_ss << ", "; // Use comma separator in table
                            gpu_list_ss << info.gpuInfo[j].physicalId;
                            if (j == 0) max_nvlinks = info.gpuInfo[j].maxNumNvLinks; 
                            first_gpu = false;
                        }

                        std::string gpu_list = gpu_list_ss.str();
                        if (gpu_list.empty()) gpu_list = "N/A";

                        std::cout << std::left << std::setw(15) << info.partitionId
                                  << std::left << std::setw(15) << info.numGpus
                                  << std::left << std::setw(25) << gpu_list
                                  << std::left << std::setw(20) << max_nvlinks 
                                  << std::left << (info.isActive ? "ACTIVE" : "INACTIVE")
                                  << std::endl;
                    }
                }
            }
            break;
        }

        case 1: { // Activate a Partition
            if (partitionId == PARTITION_ID_NOT_SET) { 
                 std::cout << "Error: Partition ID (-p) is required for activation." << std::endl;
                 return FM_ST_BADPARAM;
            }
            fmReturn = fmActivateFabricPartition(fmHandle, partitionId);
            if (fmReturn == FM_ST_SUCCESS) {
                std::cout << "Successfully sent activation request for partition " << partitionId << std::endl;
                updateStateFile(partitionId, true);
            } else {
                printFmError("activate partition", fmReturn);
            }
            break;
        }

        case 2: { // Deactivate a Partition
            if (partitionId == PARTITION_ID_NOT_SET) { 
                 std::cout << "Error: Partition ID (-p) is required for deactivation." << std::endl;
                 return FM_ST_BADPARAM;
            }
            fmReturn = fmDeactivateFabricPartition(fmHandle, partitionId);
            if (fmReturn == FM_ST_SUCCESS) {
                std::cout << "Successfully sent deactivation request for partition " << partitionId << std::endl;
                updateStateFile(partitionId, false);
            } else {
                printFmError("deactivate partition", fmReturn);
            }
            break;
        }

        case 3: { // Restore Active Partitions
            auto activePartitions = readState();
            
            fmActivatedFabricPartitionList_t partitionsToRestore = {0};
            partitionsToRestore.version = fmActivatedFabricPartitionList_version;
            
            if (activePartitions.size() > FM_MAX_FABRIC_PARTITIONS) {
                std::cout << "Error: Number of active partitions in state file exceeds limit." << std::endl;
                return FM_ST_BADPARAM;
            }

            partitionsToRestore.numPartitions = activePartitions.size();
            for(size_t i = 0; i < activePartitions.size(); ++i) {
                partitionsToRestore.partitionIds[i] = activePartitions[i];
            }

            std::cout << "Restoring " << partitionsToRestore.numPartitions << " active partition(s)..." << std::endl;

            fmReturn = fmSetActivatedFabricPartitions(fmHandle, &partitionsToRestore);

            if (fmReturn == FM_ST_SUCCESS) {
                std::cout << "Successfully restored active partitions." << std::endl;
            } else {
                printFmError("restore active partitions", fmReturn);
            }
            break;
        }

        default:
            std::cout << "Error: Invalid operation specified (" << operation << ")." << std::endl;
            fmReturn = FM_ST_BADPARAM;
            break;
    }

    if (outputFormat != "csv" || fmReturn != FM_ST_SUCCESS) {
        std::cout << std::endl;
    }
    return fmReturn;
}


int main(int argc, char **argv)
{
    fmReturn_t fmReturn = FM_ST_SUCCESS;
    fmHandle_t fmHandle = NULL;
    char hostIpAddress[16] = "127.0.0.1";
    unsigned int operation = 99;         
    
    const fmFabricPartitionId_t PARTITION_ID_NOT_SET = 9999; 
    fmFabricPartitionId_t partitionId = PARTITION_ID_NOT_SET;
    
    std::string outputFormat = "table"; 

    bool runInteractive = (argc == 1); 

    //parse cli args
    for (int i = 1; i < argc; ++i) {
        if ((strcmp(argv[i], "-i") == 0 || strcmp(argv[i], "--ip") == 0) && i + 1 < argc) {
            strncpy(hostIpAddress, argv[i+1], sizeof(hostIpAddress) - 1);
            i++; 
            runInteractive = false;
        } else if ((strcmp(argv[i], "-o") == 0 || strcmp(argv[i], "--operation") == 0) && i + 1 < argc) {
            operation = std::stoul(argv[i+1]); 
            i++; 
            runInteractive = false;
        } else if ((strcmp(argv[i], "-p") == 0 || strcmp(argv[i], "--partition") == 0) && i + 1 < argc) {
            partitionId = std::stoul(argv[i+1]); 
            i++; 
        } else if ((strcmp(argv[i], "-f") == 0 || strcmp(argv[i], "--format") == 0) && i + 1 < argc) {
            std::string formatArg = argv[i+1];
            if (formatArg == "csv") {
                outputFormat = "csv";
            } else if (formatArg != "table") {
                std::cout << "Error: Unsupported format '" << formatArg << "'. Use 'csv' or 'table'.\n";
                return FM_ST_BADPARAM;
            }
            i++;
            runInteractive = false;
        } else if (!runInteractive) {
            std::cout << "Usage: " << argv[0] << " [-i <IP>] -o <OP> [-p <ID>] [-f <FORMAT>]\n"
                      << "  -i, --ip <IP>        : IP address of Fabric Manager (default: 127.0.0.1)\n"
                      << "  -o, --operation <N>  : 0=List, 1=Activate, 2=Deactivate, 3=Restore\n"
                      << "  -p, --partition <ID> : Partition ID (for Activate/Deactivate)\n"
                      << "  -f, --format <FORMAT>: Output format for op 0 (csv or table, default: table)\n"
                      << "Running without options starts interactive mode.\n";
            return FM_ST_BADPARAM;
        }
    }
    
    // handle Connection based on mode
    
    if (!runInteractive && operation != 99) {
        // cli mode -> already know ip
    } else {
        // interactive mode --> get ip from user input
        std::string inputBuffer;
        std::cout << "Please input an IP address to connect to (default: 127.0.0.1). Press Enter to accept default: ";
        std::getline(std::cin, inputBuffer);

        if (!inputBuffer.empty()) {
            if (inputBuffer.length() >= sizeof(hostIpAddress)) {
                std::cout << "Invalid IP address (too long).\n" << std::endl;
                return FM_ST_BADPARAM; 
            }
            strncpy(hostIpAddress, inputBuffer.c_str(), sizeof(hostIpAddress) - 1);
        }
    }
    
    fmReturn = fmLibInit();
    if (FM_ST_SUCCESS != fmReturn) return fmReturn;

    fmConnectParams_t connectParams = {0}; 
    connectParams.version = fmConnectParams_version; 
    connectParams.timeoutMs = 1000; 
    connectParams.addressIsUnixSocket = 0;
    strncpy(connectParams.addressInfo, hostIpAddress, sizeof(connectParams.addressInfo));
    connectParams.addressInfo[sizeof(connectParams.addressInfo) - 1] = '\0'; 
    
    fmReturn = fmConnect(&connectParams, &fmHandle);
    if (fmReturn != FM_ST_SUCCESS) {
        printFmError("connect to Fabric Manager", fmReturn);
        fmLibShutdown(); 
        return fmReturn;
    }
    
    if (outputFormat != "csv" && operation != 3) {
        std::cout << "Successfully connected to Fabric Manager at " << hostIpAddress << std::endl;
    }
    
    //execute Command or Interactive loop 
    if (!runInteractive && operation != 99) {
        // non-interactive mode: run  single command
        fmReturn = executeOperation(fmHandle, operation, partitionId, outputFormat);
    } else {
        // interactive mode: run the menu loop
        while (true)
        {
            printMenu();
            if (!(std::cin >> operation)) {
                clearCin(); 
                continue;
            }
            
            if (operation == 4) break; 
            
            partitionId = PARTITION_ID_NOT_SET; 
            if (operation == 1 || operation == 2) {
                std::cout << "Input Shared Fabric Partition ID: \n";
                if (!(std::cin >> partitionId)) { 
                     clearCin(); 
                     continue;
                }
                if (partitionId >= FM_MAX_FABRIC_PARTITIONS) continue;
            }
            
            executeOperation(fmHandle, operation, partitionId, "table");
        }
    }

    /* Clean */
    fmDisconnect(fmHandle);
    fmLibShutdown();
    
    return fmReturn; 
}
