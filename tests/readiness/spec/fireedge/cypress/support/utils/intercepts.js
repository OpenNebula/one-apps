/* ------------------------------------------------------------------------- *
 * Copyright 2002-2023, OpenNebula Project, OpenNebula Systems               *
 *                                                                           *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may   *
 * not use this file except in compliance with the License. You may obtain   *
 * a copy of the License at                                                  *
 *                                                                           *
 * http://www.apache.org/licenses/LICENSE-2.0                                *
 *                                                                           *
 * Unless required by applicable law or agreed to in writing, software       *
 * distributed under the License is distributed on an "AS IS" BASIS,         *
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  *
 * See the License for the specific language governing permissions and       *
 * limitations under the License.                                            *
 * ------------------------------------------------------------------------- */
const PROVIDER = {
  LIST: {
    method: 'GET',
    url: '/fireedge/api/provider',
    name: 'getProviderList',
  },
  DETAIL: {
    method: 'GET',
    url: /\/provider\/\d+/,
    name: 'getProvider',
  },
  CONNECTION: {
    method: 'GET',
    url: '/fireedge/api/provider/connection/*',
    name: 'getProviderConnection',
  },
  CREATE: {
    method: 'POST',
    url: '/fireedge/api/provider',
    name: 'createProvider',
  },
  UPDATE: {
    method: 'PUT',
    url: '/fireedge/api/provider/*',
    name: 'updateProvider',
  },
  DELETE: {
    method: 'DELETE',
    url: '/fireedge/api/provider/*',
    name: 'deleteProvider',
  },
}

const PROVISION = {
  LIST: {
    method: 'GET',
    url: '/fireedge/api/provision',
    name: 'getProvisionList',
  },
  DETAIL: {
    method: 'GET',
    url: /\/provision\/\d+/,
    name: 'getProvision',
  },
  CREATE: {
    method: 'POST',
    url: '/fireedge/api/provision',
    name: 'createProvision',
  },
  CONFIGURE: {
    method: 'PUT',
    url: '/fireedge/api/provision/configure/*',
    name: 'configureProvision',
  },
  DELETE: {
    method: 'DELETE',
    url: '/fireedge/api/provision/*',
    name: 'deleteProvision',
  },
  CLUSTER_LIST: {
    method: 'GET',
    url: '/fireedge/api/provision/resource/cluster',
    name: 'getProvisionClusterList',
  },
  HOST_LIST: {
    method: 'GET',
    url: '/fireedge/api/provision/resource/host',
    name: 'getProvisionHostList',
  },
  DATASTORE_LIST: {
    method: 'GET',
    url: '/fireedge/api/provision/resource/datastore',
    name: 'getProvisionDatastoreList',
  },
  NETWORK_LIST: {
    method: 'GET',
    url: '/fireedge/api/provision/resource/network',
    name: 'getProvisionNetworkList',
  },
}

const CLUSTER = {
  CLUSTERS: {
    method: 'GET',
    url: /\/fireedge\/api\/clusterpool\/info\/?(?:\?.*)?$/,
    name: 'getClusterList',
  },
  CLUSTER: {
    method: 'GET',
    url: '/fireedge/api/cluster/info/*',
    name: 'getClusterInfo',
  },
  CLUSTER_ADD_HOST: {
    method: 'POST',
    url: '/fireedge/api/cluster/addhost/*',
    name: 'addHostCluster',
  },
  CLUSTER_ADD_VNET: {
    method: 'PUT',
    url: '/fireedge/api/cluster/addvnet/*',
    name: 'addVnetCluster',
  },
  CLUSTER_ADD_DATASTORE: {
    method: 'PUT',
    url: '/fireedge/api/cluster/adddatastore/*',
    name: 'addDatastoreCluster',
  },
  CLUSTER_REMOVE_HOST: {
    method: 'DELETE',
    url: '/fireedge/api/cluster/delhost/*',
    name: 'removeHostCluster',
  },
  CLUSTER_REMOVE_VNET: {
    method: 'DELETE',
    url: '/fireedge/api/cluster/delvnet/*',
    name: 'removeVnetCluster',
  },
  CLUSTER_REMOVE_DATASTORE: {
    method: 'DELETE',
    url: '/fireedge/api/cluster/deldatastore/*',
    name: 'removeDatastoreCluster',
  },
  CLUSTER_ALLOCATE: {
    method: 'PUT',
    url: '/fireedge/api/cluster/allocate',
    name: 'allocateCluster',
  },
  CLUSTER_RENAME: {
    method: 'PUT',
    url: '/fireedge/api/cluster/rename/*',
    name: 'renameCluster',
  },
  CLUSTER_DELETE: {
    method: 'DELETE',
    url: '/fireedge/api/cluster/delete/*',
    name: 'deleteCluster',
  },
  CLUSTER_UPDATE: {
    method: 'PUT',
    url: '/fireedge/api/cluster/update/*',
    name: 'updateCluster',
  },
}

const VM = {
  VMS: {
    method: 'GET',
    url: /\/fireedge\/api\/vmpool\/infoextended\/?(?:\?.*)?$/,
    name: 'getVmList',
  },
  VM: {
    method: 'GET',
    url: '/fireedge/api/vm/info/*',
    name: 'getVmInfo',
  },
  VM_UPDATE_CONF: {
    method: 'PUT',
    url: '/fireedge/api/vm/updateconf/*',
    name: 'updateVMConf',
  },
  VM_ACTION: {
    method: 'PUT',
    url: '/fireedge/api/vm/action/*',
    name: 'getVmAction',
  },
  VM_LOCK: {
    method: 'PUT',
    url: '/fireedge/api/vm/lock/*',
    name: 'getVMLock',
  },
  VM_UNLOCK: {
    method: 'PUT',
    url: '/fireedge/api/vm/unlock/*',
    name: 'getVMUnlock',
  },
  VM_CHANGE_MOD: {
    method: 'PUT',
    url: '/fireedge/api/vm/chmod/*',
    name: 'getVMChangeMod',
  },
  VM_CHANGE_OWN: {
    method: 'PUT',
    url: '/fireedge/api/vm/chown/*',
    name: 'getVMChangeOwn',
  },
  VM_RENAME: {
    method: 'PUT',
    url: '/fireedge/api/vm/rename/*',
    name: 'vmRename',
  },
  VM_RESIZE: {
    method: 'PUT',
    url: '/fireedge/api/vm/resize/*',
    name: 'vmResize',
  },
  VM_UPDATENIC: {
    method: 'PUT',
    url: '/fireedge/api/vm/updatenic/*',
    name: 'vmUpdateNic',
  },
  VM_SNAPSHOT_CREATE: {
    method: 'POST',
    url: '/fireedge/api/vm/snapshotcreate/*',
    name: 'getVMSnapshotCreate',
  },
  VM_SNAPSHOT_REVERT: {
    method: 'POST',
    url: '/fireedge/api/vm/snapshotrevert/*',
    name: 'getVMSnapshotRevert',
  },
  VM_SNAPSHOT_DELETE: {
    method: 'DELETE',
    url: '/fireedge/api/vm/snapshotdelete/*',
    name: 'getVMSnapshotDelete',
  },
  VM_ATTACH_DISK: {
    method: 'PUT',
    url: '/fireedge/api/vm/attach/*',
    name: 'vmAttachDisk',
  },
  VM_ATTACH_PCI: {
    method: 'PUT',
    url: '/fireedge/api/vm/attachpci/*',
    name: 'vmAttachPci',
  },
  VM_DETACH_PCI: {
    method: 'PUT',
    url: '/fireedge/api/vm/detachpci/*',
    name: 'vmDetachPci',
  },
}

const USER = {
  USERS: {
    method: 'GET',
    url: /\/fireedge\/api\/userpool\/info\/?(?:\?.*)?$/,
    name: 'getUserList',
  },
  USER: {
    method: 'GET',
    url: '/fireedge/api/user/info/*',
    name: 'getUserInfo',
  },
  USER_INFO: {
    method: 'GET',
    url: '/fireedge/api/user/info',
    name: 'getUserProfile',
  },
  USER_UPDATE: {
    method: 'PUT',
    url: '/fireedge/api/user/update/*',
    name: 'updateUser',
  },
  USER_QUOTA_UPDATE: {
    method: 'PUT',
    url: '/fireedge/api/user/quota/*',
    name: 'updateUserQuota',
  },
  USER_LOCK: {
    method: 'PUT',
    url: '/fireedge/api/user/enable/*',
    name: 'lockUser',
  },
  USER_LOGIN: {
    method: 'POST',
    url: '/fireedge/api/user/login',
    name: 'loginTokenUser',
  },
  USER_UNLOCK: {
    method: 'PUT',
    url: '/fireedge/api/user/enable/*',
    name: 'unlockUser',
  },
  USER_CREATE: {
    method: 'POST',
    url: '/fireedge/api/user/allocate',
    name: 'userCreate',
  },
  USER_DELETE: {
    method: 'DELETE',
    url: '/fireedge/api/user/delete/*',
    name: 'deleteUser',
  },
  USER_CHAUTH: {
    method: 'PUT',
    URL: '/fireedge/api/user/chauth',
    name: 'chauthUser',
  },
  USER_CHGRP: {
    method: 'PUT',
    URL: '/fireedge/api/user/chgrp',
    name: 'chgrpUser',
  },
  USER_ENABLE_2FA: {
    method: 'POST',
    URL: '/fireedge/api/tfa',
    name: 'enable2FA',
  },
  USER_QR_2FA: {
    method: 'GET',
    URL: '/fireedge/api/tfa',
    name: 'getQr2FA',
  },
  USER_DISABLE_2FA: {
    method: 'DELETE',
    URL: '/fireedge/api/tfa',
    name: 'disable2FA',
  },
  USER_CHANGE_PASSWORD: {
    method: 'PUT',
    URL: 'fireedge/api/user/passwd/*',
    name: 'changeUserPassword',
  },
}

const SECGROUP = {
  SECGROUPS: {
    method: 'GET',
    url: /\/fireedge\/api\/secgrouppool\/info\/?(?:\?.*)?$/,
    name: 'getSecGroupList',
  },
  SECGROUP: {
    method: 'GET',
    url: '/fireedge/api/secgroup/info/*',
    name: 'getSecGroupInfo',
  },
  SECGROUP_UPDATE: {
    method: 'PUT',
    url: '/fireedge/api/secgroup/update/*',
    name: 'getSecGroupUpdate',
  },
  SECGROUP_CHANGE_MOD: {
    method: 'PUT',
    url: '/fireedge/api/secgroup/chmod/*',
    name: 'getSecGroupChmod',
  },
  SECGROUP_DELETE: {
    method: 'DELETE',
    url: '/fireedge/api/secgroup/delete/*',
    name: 'getDeleteSecGroup',
  },
  SECGROUP_CLONE: {
    method: 'POST',
    url: '/fireedge/api/secgroup/clone/*',
    name: 'getCloneSecGroup',
  },
  SECGROUP_COMMIT: {
    method: 'PUT',
    url: '/fireedge/api/secgroup/commit/*',
    name: 'getCommitSecGroup',
  },
  SECGROUP_ALLOCATE: {
    method: 'POST',
    url: '/fireedge/api/secgroup/allocate',
    name: 'getAllocateSecGroup',
  },
}

const GROUP = {
  GROUPS: {
    method: 'GET',
    url: /\/fireedge\/api\/grouppool\/info\/?(?:\?.*)?$/,
    name: 'getGroupsList',
  },
  GROUP: {
    method: 'GET',
    url: '/fireedge/api/group/info/*',
    name: 'getGroupInfo',
  },
  GROUP_CREATE: {
    method: 'POST',
    url: '/fireedge/api/group/allocate',
    name: 'groupCreate',
  },
  GROUP_UPDATE: {
    method: 'PUT',
    url: '/fireedge/api/group/update/*',
    name: 'groupUpdate',
  },
  GROUP_DELETE: {
    method: 'DELETE',
    url: '/fireedge/api/group/delete/*',
    name: 'groupUpdate',
  },
  GROUP_QUOTA_UPDATE: {
    method: 'PUT',
    url: '/fireedge/api/group/quota/*',
    name: 'updateGroupQuota',
  },
  GROUP_ADMIN_ADD: {
    method: 'POST',
    url: '/fireedge/api/group/addadmin/*',
    name: 'groupAdminAdd',
  },
  GROUP_ADMIN_DELETE: {
    method: 'DELETE',
    url: '/fireedge/api/group/deladmin/*',
    name: 'groupAdminDelete',
  },
}

const SERVICE = {
  SERVICES: {
    method: 'GET',
    url: '/fireedge/api/service',
    name: 'getServicesList',
  },
  SERVICE: {
    method: 'GET',
    url: '/fireedge/api/service/*',
    name: 'getServiceInfo',
  },
  SERVICE_CHMOD: {
    method: 'POST',
    url: '/fireedge/api/service/action/*',
    name: 'serviceChmod',
  },
  SERVICE_ADD_ROLE: {
    method: 'POST',
    url: '/fireedge/api/service/*/role_action',
    name: 'serviceAddRole',
  },
  SERVICE_RECOVER_DELETE: {
    method: 'POST',
    url: '/fireedge/api/service/action/*',
    name: 'serviceRecoverDelete',
  },
  SERVICE_PERFORM_ACTION_ROLE: {
    method: 'POST',
    url: '/fireedge/api/service/*/role/*/action',
    name: 'serviceAddRole',
  },
}

const VROUTER = {
  VROUTERS: {
    method: 'GET',
    url: /\/fireedge\/api\/vrouterpool\/info\/?(?:\?.*)?$/,
    name: 'getServicesList',
  },
  VROUTER: {
    method: 'GET',
    url: '/fireedge/api/vrouter/info/*',
    name: 'getVRouterInfo',
  },
  VROUTER_CHMOD: {
    method: 'PUT',
    url: '/fireedge/api/vrouter/chmod/*',
    name: 'vrouterChmod',
  },
  VROUTER_DELETE: {
    method: 'DELETE',
    url: '/fireedge/api/vrouter/delete/*',
    name: 'vrouterRecoverDelete',
  },
}

const VROUTERTEMPLATE = {
  VROUTERTEMPLATES: {
    method: 'GET',
    url: /\/fireedge\/api\/templatepool\/info\/?(?:\?.*)?$/,
    name: 'getTemplateList',
  },
  VROUTERTEMPLATE: {
    method: 'GET',
    url: '/fireedge/api/template/info/*?*',
    name: 'getTemplateInfo',
  },
  VROUTERTEMPLATE_INSTANTIATE: {
    method: 'PUT',
    url: '/fireedge/api/vrouter/instantiate/',
    name: 'getTemplateInstatiate',
  },
  VROUTERTEMPLATE_ALLOCATE: {
    method: 'POST',
    url: '/fireedge/api/template/allocate',
    name: 'getTemplateAllocate',
  },
  VROUTERTEMPLATE_UPDATE: {
    method: 'PUT',
    url: '/fireedge/api/template/update/*',
    name: 'getTemplateUpdate',
  },
  VROUTERTEMPLATE_CLONE: {
    method: 'POST',
    url: '/fireedge/api/template/clone/*',
    name: 'getTemplateClone',
  },
  VROUTERTEMPLATE_CHANGE_OWN: {
    method: 'PUT',
    url: '/fireedge/api/template/chown/*',
    name: 'getTemplateChown',
  },
  VROUTERTEMPLATE_CHANGE_MOD: {
    method: 'PUT',
    url: '/fireedge/api/template/chmod/*',
    name: 'getTemplateChmod',
  },
  VROUTERTEMPLATE_LOCK: {
    method: 'PUT',
    url: '/fireedge/api/template/lock/*',
    name: 'getTemplateLock',
  },
  VROUTERTEMPLATE_UNLOCK: {
    method: 'PUT',
    url: '/fireedge/api/template/unlock/*',
    name: 'getTemplateUnlock',
  },
  VROUTERTEMPLATE_DELETE: {
    method: 'DELETE',
    url: '/fireedge/api/template/delete/*',
    name: 'deleteTemplate',
  },
  VROUTERTEMPLATE_RENAME: {
    method: 'PUT',
    url: '/fireedge/api/template/rename/*',
    name: 'templateRename',
  },
}

const SERVICETEMPLATE = {
  SERVICETEMPLATE_CREATE: {
    method: 'POST',
    url: '/fireedge/api/service_template',
    name: 'serviceTemplateCreate',
  },
  SERVICETEMPLATE_UPDATE: {
    method: 'POST',
    url: '/fireedge/api/service_template/action/*',
    name: 'serviceTemplateUpdate',
  },
  SERVICETEMPLATE: {
    method: 'GET',
    url: '/fireedge/api/service_template/*',
    name: 'getServiceTemplateInfo',
  },
  SERVICETEMPLATES: {
    method: 'GET',
    url: '/fireedge/api/service_template/',
    name: 'getServiceTemplateList',
  },
  SERVICETEMPLATE_CHMOD: {
    method: 'POST',
    url: '/fireedge/api/service_template/action/*',
    name: 'servicetemplateChmod',
  },
  SERVICETEMPLATE_CHOWN: {
    method: 'POST',
    url: '/fireedge/api/service_template/action/*',
    name: 'servicetemplateChown',
  },
  SERVICETEMPLATE_DELETE: {
    method: 'DELETE',
    url: '/fireedge/api/service_template/*',
    name: 'servicetemplateDelete',
  },
  SERVICETEMPLATE_INSTANTIATE: {
    method: 'POST',
    url: '/fireedge/api/service_template/action/*',
    name: 'servicetemplateInstantiate',
  },
}

const TEMPLATE = {
  TEMPLATES: {
    method: 'GET',
    url: /\/fireedge\/api\/templatepool\/info\/?(?:\?.*)?$/,
    name: 'getTemplateList',
  },
  TEMPLATE: {
    method: 'GET',
    url: '/fireedge/api/template/info/*?*',
    name: 'getTemplateInfo',
  },
  TEMPLATE_INSTANTIATE: {
    method: 'PUT',
    url: '/fireedge/api/template/instantiate/*',
    name: 'getTemplateInstatiate',
  },
  TEMPLATE_ALLOCATE: {
    method: 'PUT',
    url: '/fireedge/api/template/allocate',
    name: 'getTemplateAllocate',
  },
  TEMPLATE_UPDATE: {
    method: 'PUT',
    url: '/fireedge/api/template/update/*',
    name: 'getTemplateUpdate',
  },
  TEMPLATE_CLONE: {
    method: 'POST',
    url: '/fireedge/api/template/clone/*',
    name: 'getTemplateClone',
  },
  TEMPLATE_CHANGE_OWN: {
    method: 'PUT',
    url: '/fireedge/api/template/chown/*',
    name: 'getTemplateChown',
  },
  TEMPLATE_CHANGE_MOD: {
    method: 'PUT',
    url: '/fireedge/api/template/chmod/*',
    name: 'getTemplateChmod',
  },
  TEMPLATE_LOCK: {
    method: 'PUT',
    url: '/fireedge/api/template/lock/*',
    name: 'getTemplateLock',
  },
  TEMPLATE_UNLOCK: {
    method: 'GET',
    url: '/fireedge/api/template/unlock/*',
    name: 'getTemplateUnlock',
  },
  TEMPLATE_DELETE: {
    method: 'DELETE',
    url: '/fireedge/api/template/delete/*',
    name: 'deleteTemplate',
  },
  TEMPLATE_RENAME: {
    method: 'PUT',
    url: '/fireedge/api/template/rename/*',
    name: 'templateRename',
  },
}

const DATASTORE = {
  DATASTORES: {
    method: 'GET',
    url: /\/fireedge\/api\/datastorepool\/info\/?(?:\?.*)?$/,
    name: 'getDatastoreList',
  },
  DATASTORE: {
    method: 'GET',
    url: '/fireedge/api/datastore/info/*',
    name: 'getDatastoreInfo',
  },
  DATASTORE_CHANGE_OWN: {
    method: 'PUT',
    url: '/fireedge/api/datastore/chown/*',
    name: 'getDatastoreChown',
  },
  DATASTORE_CHANGE_MOD: {
    method: 'PUT',
    url: '/fireedge/api/datastore/chmod/*',
    name: 'getDatastoreChmod',
  },
  DATASTORE_ENABLE: {
    method: 'PUT',
    url: '/fireedge/api/datastore/enable/*',
    name: 'getDatastoreEnable',
  },
  DATASTORE_DELETE: {
    method: 'DELETE',
    url: '/fireedge/api/datastore/delete/*',
    name: 'getDeleteDatastore',
  },
  DATASTORE_UPDATE: {
    method: 'PUT',
    url: '/fireedge/api/datastore/update/*',
    name: 'getDatastoreUpdate',
  },
  DATASTORE_ALLOCATE: {
    method: 'PUT',
    url: '/fireedge/api/datastore/allocate',
    name: 'getDatastoreAllocate',
  },
}

const IMAGE = {
  IMAGES: {
    method: 'GET',
    url: /\/fireedge\/api\/imagepool\/info\/?(?:\?.*)?$/,
    name: 'getImagesList',
  },
  IMAGE: {
    method: 'GET',
    url: '/fireedge/api/image/info/*',
    name: 'getImageInfo',
  },
  IMAGE_ENABLE: {
    method: 'PUT',
    url: '/fireedge/api/image/enable/*',
    name: 'getImageEnable',
  },
  IMAGE_PERSISTENT: {
    method: 'PUT',
    url: '/fireedge/api/image/persistent/*',
    name: 'getImagePersistent',
  },
  IMAGE_LOCK: {
    method: 'PUT',
    url: '/fireedge/api/image/lock/*',
    name: 'getImageLock',
  },
  IMAGE_UNLOCK: {
    method: 'PUT',
    url: '/fireedge/api/image/unlock/*',
    name: 'getImageUnlock',
  },
  IMAGE_DELETE: {
    method: 'DELETE',
    url: '/fireedge/api/image/delete/*',
    name: 'getDeleteImage',
  },
  IMAGE_CHANGE_OWN: {
    method: 'PUT',
    url: '/fireedge/api/image/chown/*',
    name: 'getImageChown',
  },
  IMAGE_CHANGE_MOD: {
    method: 'PUT',
    url: '/fireedge/api/image/chmod/*',
    name: 'getImageChmod',
  },
  IMAGE_CLONE: {
    method: 'POST',
    url: '/fireedge/api/image/clone/*',
    name: 'getImageClone',
  },
  IMAGE_ALLOCATE: {
    method: 'POST',
    url: '/fireedge/api/image/allocate',
    name: 'getImageAllocate',
  },
}

const NETWORK = {
  NETWORKS: {
    method: 'GET',
    url: /\/fireedge\/api\/vnpool\/info\/?(?:\?.*)?$/,
    name: 'getVNetsList',
  },
  NETWORK: {
    method: 'GET',
    url: '/fireedge/api/vn/info/*',
    name: 'getVNetInfo',
  },
  NETWORK_ALLOCATE: {
    method: 'POST',
    url: '/fireedge/api/vn/allocate',
    name: 'getVNetAllocate',
  },
  NETWORK_UPDATE: {
    method: 'PUT',
    url: '/fireedge/api/vn/update/*',
    name: 'updateVNet',
  },
  NETWORK_DELETE: {
    method: 'DELETE',
    url: '/fireedge/api/vn/delete/*',
    name: 'deleteVNet',
  },
  NETWORK_RESERVE: {
    method: 'PUT',
    url: '/fireedge/api/vn/reserve/*',
    name: 'reserveVNet',
  },
  NETWORK_LOCK: {
    method: 'PUT',
    url: '/fireedge/api/vn/lock/*',
    name: 'getVNetLock',
  },
  NETWORK_UNLOCK: {
    method: 'PUT',
    url: '/fireedge/api/vn/unlock/*',
    name: 'getVNetUnlock',
  },
  NETWORK_CHANGE_MOD: {
    method: 'PUT',
    url: '/fireedge/api/vn/chmod/*',
    name: 'getVNetChmod',
  },
}

const NETWORK_TEMPLATE = {
  NETWORK_TEMPLATES: {
    method: 'GET',
    url: /\/fireedge\/api\/vntemplatepool\/info\/?(?:\?.*)?$/,
    name: 'getVNTemplateList',
  },
  NETWORK_TEMPLATE: {
    method: 'GET',
    url: '/fireedge/api/vntemplate/info/*',
    name: 'getVNTemplateInfo',
  },
  NETWORK_TEMPLATE_ALLOCATE: {
    method: 'POST',
    url: '/fireedge/api/vntemplate/allocate',
    name: 'getVNTemplateAllocate',
  },
  NETWORK_TEMPLATE_UPDATE: {
    method: 'PUT',
    url: '/fireedge/api/vntemplate/update/*',
    name: 'updateVNTemplate',
  },
  NETWORK_TEMPLATE_DELETE: {
    method: 'DELETE',
    url: '/fireedge/api/vntemplate/delete/*',
    name: 'deleteVNTemplate',
  },
  NETWORK_TEMPLATE_LOCK: {
    method: 'PUT',
    url: '/fireedge/api/vntemplate/lock/*',
    name: 'getVNTemplateLock',
  },
  NETWORK_TEMPLATE_UNLOCK: {
    method: 'PUT',
    url: '/fireedge/api/vntemplate/unlock/*',
    name: 'getVNTemplateUnlock',
  },
  NETWORK_TEMPLATE_CHANGE_MOD: {
    method: 'PUT',
    url: '/fireedge/api/vntemplate/chmod/*',
    name: 'getVNTemplateChmod',
  },
}

const MARKET = {
  MARKETS: {
    method: 'GET',
    url: /\/fireedge\/api\/marketpool\/info\/?(?:\?.*)?$/,
    name: 'getMarketList',
  },
  MARKET: {
    method: 'GET',
    url: '/fireedge/api/market/info/*',
    name: 'getMarketInfo',
  },
  MARKET_ALLOCATE: {
    method: 'POST',
    url: '/fireedge/api/market/allocate',
    name: 'allocateCluster',
  },
  MARKET_RENAME: {
    method: 'PUT',
    url: '/fireedge/api/market/rename/*',
    name: 'renameCluster',
  },
  MARKET_DELETE: {
    method: 'DELETE',
    url: '/fireedge/api/market/delete/*',
    name: 'deleteCluster',
  },
  MARKET_UPDATE: {
    method: 'PUT',
    url: '/fireedge/api/market/update/*',
    name: 'updateCluster',
  },
  MARKET_CHOWN: {
    method: 'PUT',
    url: '/fireedge/api/market/chown/*',
    name: 'chownCluster',
  },
}

const MARKETAPP = {
  MARKETAPPS: {
    method: 'GET',
    url: /\/fireedge\/api\/marketapppool\/info\/?(?:\?.*)?$/,
    name: 'getMarketAppsList',
  },
  MARKETAPP: {
    method: 'GET',
    url: '/fireedge/api/marketapp/info/*',
    name: 'getMarketAppInfo',
  },
  MARKETAPP_VMIMPORT: {
    method: 'POST',
    url: '/fireedge/api/marketapp/vmimport/*',
    name: 'getmarketVMImport',
  },
  MARKETAPP_EXPORT: {
    method: 'POST',
    url: '/fireedge/api/marketapp/export/*',
    name: 'getMarketAppsExport',
  },
  MARKETAPP_UPDATE: {
    method: 'PUT',
    url: '/fireedge/api/marketapp/update/*',
    name: 'updateMarketApp',
  },
  MARKETAPP_LOCK: {
    method: 'PUT',
    url: '/fireedge/api/marketapp/lock/*',
    name: 'getMarketAppLock',
  },
  MARKETAPP_UNLOCK: {
    method: 'PUT',
    url: '/fireedge/api/marketapp/unlock/*',
    name: 'getMarketAppUnlock',
  },
  MARKETAPP_DELETE: {
    method: 'DELETE',
    url: '/fireedge/api/marketapp/delete/*',
    name: 'deleteMarketApp',
  },
  MARKETAPP_ENABLE: {
    method: 'PUT',
    url: '/fireedge/api/marketapp/enable/*',
    name: 'getMarketAppEnable',
  },
  MARKETAPP_CHANGE_OWN: {
    method: 'PUT',
    url: '/fireedge/api/marketapp/chown/*',
    name: 'getMarketappChown',
  },
}

const HOST = {
  HOSTS: {
    method: 'GET',
    url: /\/fireedge\/api\/hostpool\/info\/?(?:\?.*)?$/,
    name: 'getHostList',
  },
  HOSTPOOL_ADMININFO: {
    method: 'GET',
    url: '/fireedge/api/hostpool/admininfo',
    name: 'getHostPoolAdmin',
  },
  HOST: {
    method: 'GET',
    url: '/fireedge/api/host/info/*',
    name: 'getHostInfo',
  },
  HOST_ALLOCATE: {
    method: 'PUT',
    url: '/fireedge/api/host/allocate',
    name: 'getHostAllocate',
  },
  HOST_UPDATE: {
    method: 'PUT',
    url: '/fireedge/api/host/update/*',
    name: 'updateHost',
  },
  HOST_DELETE: {
    method: 'DELETE',
    url: '/fireedge/api/host/delete/*',
    name: 'deleteHost',
  },
  HOST_CHANGE_STATUS: {
    method: 'PUT',
    url: '/fireedge/api/host/status/*',
    name: 'hostChangeStatus',
  },
  HOST_RENAME: {
    method: 'PUT',
    url: '/fireedge/api/host/rename/*',
    name: 'hostRename',
  },
}

const VDC = {
  VDCS: {
    method: 'GET',
    url: /\/fireedge\/api\/vdcpool\/info\/?(?:\?.*)?$/,
    name: 'getVdcList',
  },
  VDC: {
    method: 'GET',
    url: '/fireedge/api/vdc/info/*',
    name: 'getVdcInfo',
  },
  VDC_UPDATE: {
    method: 'PUT',
    url: '/fireedge/api/vdc/updateVdc/*',
    name: 'vdcUpdate',
  },
  VDC_CREATE: {
    method: 'POST',
    url: '/fireedge/api/vdc/create',
    name: 'vdcCreate',
  },
  VDC_DELETE: {
    method: 'DELETE',
    url: '/fireedge/api/vdc/delete/*',
    name: 'vdcDelete',
  },
}

const VMGROUP = {
  VMGROUPS: {
    method: 'GET',
    url: /\/fireedge\/api\/vmgrouppool\/info\/?(?:\?.*)?$/,
    name: 'getVmgroupList',
  },
  VMGROUP: {
    method: 'GET',
    url: '/fireedge/api/vmgroup/info/*',
    name: 'getVmgroupInfo',
  },
  VMGROUP_UPDATE: {
    method: 'PUT',
    url: '/fireedge/api/vmgroup/update/*',
    name: 'vmgroupUpdate',
  },
  VMGROUP_LOCK: {
    method: 'PUT',
    url: '/fireedge/api/vmgroup/lock/*',
    name: 'vmgroupLock',
  },
  VMGROUP_UNLOCK: {
    method: 'PUT',
    url: '/fireedge/api/vmgroup/unlock/*',
    name: 'vmgroupUnlock',
  },
  VMGROUP_CREATE: {
    method: 'POST',
    url: '/fireedge/api/vmgroup/allocate/',
    name: 'vmgroupCreate',
  },
  VMGROUP_CHMOD: {
    method: 'PUT',
    url: '/fireedge/api/vmgroup/chmod/*',
    name: 'vmgroupChmod',
  },
  VMGROUP_DELETE: {
    method: 'DELETE',
    url: '/fireedge/api/vmgroup/delete/*',
    name: 'vmgroupDelete',
  },
}

const BACKUPJOB = {
  BACKUPJOBS: {
    method: 'GET',
    url: /\/fireedge\/api\/backupjobpool\/info\/?(?:\?.*)?$/,
    name: 'getBackupJobList',
  },
  BACKUPJOB: {
    method: 'GET',
    url: '/fireedge/api/backupjob/info/*',
    name: 'getBackupJobInfo',
  },
  BACKUPJOB_UPDATE: {
    method: 'PUT',
    url: '/fireedge/api/backupjob/update/',
    name: 'backupjobUpdate',
  },
  BACKUPJOB_LOCK: {
    method: 'PUT',
    url: '/fireedge/api/backupjob/lock/*',
    name: 'backupjobLock',
  },
  BACKUPJOB_UNLOCK: {
    method: 'PUT',
    url: '/fireedge/api/backupjob/unlock/*',
    name: 'backupjobUnlock',
  },
  BACKUPJOB_CREATE: {
    method: 'POST',
    url: '/fireedge/api/backupjob/allocate/',
    name: 'backupjobCreate',
  },
  BACKUPJOB_CHMOD: {
    method: 'PUT',
    url: '/fireedge/api/backupjob/chmod/*',
    name: 'backupjobChmod',
  },
  BACKUPJOB_DELETE: {
    method: 'DELETE',
    url: '/fireedge/api/backupjob/delete/*',
    name: 'backupjobDelete',
  },
  BACKUPJOB_CHANGE_OWN: {
    method: 'PUT',
    url: '/fireedge/api/backupjob/chown/*',
    name: 'getBackupJobChown',
  },
  BACKUPJOB_CHANGE_MOD: {
    method: 'PUT',
    url: '/fireedge/api/backupjob/chmod/*',
    name: 'getBackupJobChmod',
  },
}

const ACL = {
  ACLS: {
    method: 'GET',
    url: '/fireedge/api/acl/info',
    name: 'getAclList',
  },
  ACL_CREATE: {
    method: 'POST',
    url: '/fireedge/api/acl/addrule/',
    name: 'aclCreate',
  },
  ACL_DELETE: {
    method: 'DELETE',
    url: '/fireedge/api/acl/delrule/*',
    name: 'aclDelete',
  },
}

const SUPPORT = {
  SUPPORT_LOGIN: {
    method: 'POST',
    url: '/fireedge/api/zendesk/login',
    name: 'supportLogin',
  },
  SUPPORT_CREATE_TICKET: {
    method: 'POST',
    url: '/fireedge/api/zendesk',
    name: 'createTicket',
  },
  UPDATE_TICKET: {
    method: 'PUT',
    url: '/fireedge/api/zendesk/*',
    name: 'updateTicket',
  },
  SUPPORT_TICKETS: {
    method: 'GET',
    url: '/fireedge/api/zendesk',
    name: 'getTickets',
  },
}

const ZONE = {
  ZONES: {
    method: 'GET',
    url: /\/fireedge\/api\/zonepool\/info\/?(?:\?.*)?$/,
    name: 'getZoneList',
  },
  ZONE: {
    method: 'GET',
    url: '/fireedge/api/zone/info/*',
    name: 'getZoneInfo',
  },
}

const SETTINGS = {
  LOGO: {
    method: 'GET',
    url: '/fireedge/api/logo/',
    name: 'getLogo',
  },
}

const SUNSTONE = {
  ...ACL,
  ...BACKUPJOB,
  ...CLUSTER,
  ...VM,
  ...USER,
  ...GROUP,
  ...SECGROUP,
  ...TEMPLATE,
  ...SERVICE,
  ...SERVICETEMPLATE,
  ...VROUTER,
  ...VROUTERTEMPLATE,
  ...SETTINGS,
  ...SUPPORT,
  ...DATASTORE,
  ...IMAGE,
  ...NETWORK,
  ...NETWORK_TEMPLATE,
  ...MARKET,
  ...MARKETAPP,
  ...HOST,
  ...VDC,
  ...VMGROUP,
  ...ZONE,
  LOGIN: {
    method: 'POST',
    url: '/fireedge/api/auth',
    name: 'loginUser',
  },
}

export { PROVIDER, PROVISION, SUNSTONE }
