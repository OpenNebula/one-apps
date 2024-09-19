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
import {
  beforeAllCluster,
  clusterGUI,
  updateGUI,
  deleteGUI,
  validateTabs,
  updateTemplateGUI,
  validateCardView,
  afterAllCluster,
} from '@common/clusters'

import { adminContext } from '@utils/constants'

const { Host, VNet, Datastore } = require('@models')

// Hosts to use in cluster tests. This hosts will be created in before all tests function.
const hosts = [
  {
    host: new Host(),
    template: {
      hostname: 'host0',
      imMad: 'dummy',
      vmmMad: 'dummy',
    },
  },
  {
    host: new Host(),
    template: {
      hostname: 'host1',
      imMad: 'dummy',
      vmmMad: 'dummy',
    },
  },
  {
    host: new Host(),
    template: {
      hostname: 'host2',
      imMad: 'dummy',
      vmmMad: 'dummy',
    },
  },
]

// Vnets to use in cluster tests. This hosts will be created in before all tests function.
const vnets = [
  {
    vnet: new VNet(),
    template: {
      NAME: 'vnet0',
      VN_MAD: 'bridge',
    },
  },
  {
    vnet: new VNet(),
    template: {
      NAME: 'vnet1',
      VN_MAD: 'bridge',
    },
  },
  {
    vnet: new VNet(),
    template: {
      NAME: 'vnet2',
      VN_MAD: 'bridge',
    },
  },
]

// Datastores to use in cluster tests. This hosts will be created in before all tests function.
const datastores = [
  {
    datastore: new Datastore(),
    template: {
      NAME: 'ds0',
      TYPE: 'SYSTEM_DS',
      TM_MAD: 'ssh',
    },
  },
  {
    datastore: new Datastore(),
    template: {
      NAME: 'ds1',
      TYPE: 'SYSTEM_DS',
      TM_MAD: 'ssh',
    },
  },
  {
    datastore: new Datastore(),
    template: {
      NAME: 'ds2',
      TYPE: 'SYSTEM_DS',
      TM_MAD: 'ssh',
    },
  },
]

// Clusters to use in create tests.
const clusters = {
  clusterWithoutResources: {
    general: {
      name: 'Cluster without resources',
    },
  },
  clusterWithHosts: {
    general: {
      name: 'Cluster only with hosts',
    },
    hosts: [hosts[0], hosts[1]],
  },
  clusterWithVnets: {
    general: {
      name: 'Cluster only with vnets',
    },
    vnets: [vnets[0], vnets[1]],
  },
  clusterWithDatastores: {
    general: {
      name: 'Cluser only with datastores',
    },
    datastores: [datastores[1], datastores[2]],
  },
  clusterWithOneResource: {
    general: {
      name: 'Cluster with one resource of each kind',
    },
    hosts: [hosts[0]],
    vnets: [vnets[0]],
    datastores: [datastores[1]],
  },
  clusterWithThreeResource: {
    general: {
      name: 'Cluster with three resources of each kind',
    },
    hosts: [hosts[0], hosts[1], hosts[2]],
    vnets: [vnets[0], vnets[1], vnets[2]],
    datastores: [datastores[0], datastores[1], datastores[2]],
  },
}

// Clusters to use in update tests.
const updateClusters = {
  updateWithoutChanges: {
    initialData: {
      general: {
        name: 'Cluster to update without any changes',
      },
      hosts: [hosts[0]],
      vnets: [vnets[0]],
      datastores: [datastores[0]],
    },
    updateData: {},
    finalData: {
      general: {
        name: 'Cluster to update without any changes',
      },
      hosts: [hosts[0]],
      vnets: [vnets[0]],
      datastores: [datastores[0]],
    },
  },
  rename: {
    initialData: {
      general: {
        name: 'Cluster to update with rename',
      },
      hosts: [hosts[0]],
      vnets: [vnets[0]],
      datastores: [datastores[0]],
    },
    updateData: {
      general: {
        name: 'Cluster to update with rename - UPDATED',
      },
    },
    finalData: {
      general: {
        name: 'Cluster to update with rename - UPDATED',
      },
      hosts: [hosts[0]],
      vnets: [vnets[0]],
      datastores: [datastores[0]],
    },
  },
  addResources: {
    initialData: {
      general: {
        name: 'Cluster to update adding resources',
      },
      hosts: [hosts[0]],
      vnets: [vnets[0]],
      datastores: [datastores[0]],
    },
    updateData: {
      hosts: {
        add: [hosts[1]],
      },
      vnets: {
        add: [vnets[1]],
      },
      datastores: {
        add: [datastores[1]],
      },
    },
    finalData: {
      general: {
        name: 'Cluster to update adding resources',
      },
      hosts: [hosts[0], hosts[1]],
      vnets: [vnets[0], vnets[1]],
      datastores: [datastores[0], datastores[1]],
    },
  },
  removeResources: {
    initialData: {
      general: {
        name: 'Cluster to update removing resources',
      },
      hosts: [hosts[0]],
      vnets: [vnets[0]],
      datastores: [datastores[0]],
    },
    updateData: {
      hosts: {
        remove: [hosts[0]],
      },
      vnets: {
        remove: [vnets[0]],
      },
      datastores: {
        remove: [datastores[0]],
      },
    },
    finalData: {
      general: {
        name: 'Cluster to update removing resources',
      },
      hosts: [],
      vnets: [],
      datastores: [],
    },
  },
  addAndRemoveResources: {
    initialData: {
      general: {
        name: 'Cluster to update adding and removing resources',
      },
      hosts: [hosts[0]],
      vnets: [vnets[0]],
      datastores: [datastores[0]],
    },
    updateData: {
      hosts: {
        add: [hosts[1]],
        remove: [hosts[0]],
      },
      vnets: {
        add: [vnets[1]],
        remove: [vnets[0]],
      },
      datastores: {
        add: [datastores[1]],
        remove: [datastores[0]],
      },
    },
    finalData: {
      general: {
        name: 'Cluster to update adding and removing resources',
      },
      hosts: [hosts[1]],
      vnets: [vnets[1]],
      datastores: [datastores[1]],
    },
  },
}

// Clusters to use in delete tests.
const deleteCluster = {
  general: {
    name: 'Cluster to delete',
  },
}

// Clusters to use in validate tabs tests.
const validateTabsClusters = {
  clusterWithResources: {
    general: {
      name: 'Cluster with resources to validate tabs',
    },
    hosts: [hosts[0], hosts[1], hosts[2]],
    vnets: [vnets[0], vnets[1], vnets[2]],
    datastores: [datastores[0], datastores[1], datastores[2]],
  },
  clusterWithoutResources: {
    general: {
      name: 'Cluster without resources to validate tabs',
    },
  },
}

// Clusters to use in update template tests.
const updateTemplateCluster = {
  general: {
    name: 'Cluster to update CPU and memory',
    cpu: '50',
    memory: '25',
  },
}

// Clusters to use in validate card view tests.
const validateCardViewCluster = {
  general: {
    name: 'Cluster to validate card view',
  },
  hosts: [hosts[0]],
  vnets: [vnets[0], vnets[1]],
  datastores: [datastores[0], datastores[1], datastores[2]],
}

describe('Sunstone GUI in Clusters tab', function () {
  context('Oneadmin', adminContext, function () {
    before(function () {
      beforeAllCluster({
        hosts,
        vnets,
        datastores,
      })
    })

    beforeEach(function () {
      cy.visit(`${Cypress.config('baseUrl')}/sunstone`, {
        qs: { externalToken: Cypress.env('TOKEN') },
      })
    })

    // eslint-disable-next-line mocha/no-setup-in-describe
    Object.entries(clusters).forEach(([key, value]) =>
      it(`Should create cluster: ${value.general.name}`, function () {
        clusterGUI(value)
      })
    )

    // eslint-disable-next-line mocha/no-setup-in-describe
    Object.entries(updateClusters).forEach(([key, value]) =>
      it(`Should update cluster: ${value.initialData.general.name}`, function () {
        updateGUI(value)
      })
    )

    it('Should delete cluster', function () {
      deleteGUI(deleteCluster)
    })

    // eslint-disable-next-line mocha/no-setup-in-describe
    Object.entries(validateTabsClusters).forEach(([key, value]) =>
      it(`Should check all cluster tabs in: ${value.general.name}`, function () {
        validateTabs(value)
      })
    )

    it('Should update allocated CPU and memory', function () {
      updateTemplateGUI(updateTemplateCluster)
    })

    it('Should validate card view', function () {
      validateCardView(validateCardViewCluster)
    })

    after(function () {
      afterAllCluster()
    })
  })
})
