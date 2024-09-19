# FireEdge testing

FireEdge testing server cypress

## Requeriments
- [Node.js 10.21 or later](https://nodejs.org/en/)

## Build & Run

- **npm i** (this command import the node dependecies).
- **npm run cypress:run** (this run the testing script (FUNCTIONALITY). this will generate a file with the results called  "results.json" in "../../results")
- **npm run cypress:run-kvm** (this run the testing script (KVM). this will generate a file with the results called  "results.json" in "../../results")

**PD:** you must go to the path **var/lib/one/readiness/spec/fireedge/** and then execute the commands

## Development
- **npm run cypress:open** (this run the testing script. in "dev" mode. this does not generate a result file)


## Troubleshooting

In centOS need install:
- Xvfb: `yum install Xvfb`
- Google Chrome: `wget https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm && yum install ./google-chrome-stable_current_*.rpm`

## Folder structure

To develop the Cypress test is important to know the folder structure that we are using, so in the following sections, you will find an explanation for each of the folders present inside the cypress folder.

### Fixtures folder

This folder contains `.json` files that contain static data that won't change (constants). All this data will be accessible in the code by executing `cy.fixture('<json file name>')`. For example: `cy.fixture('auth')`.

### Integration folder

Inside this folder are located all the tests that the tester will perform. They are identified by their extension `.spec.js`.
Here, the code is split into two folders, one for the `provision app`, and the second for the `sunstone app`.

### Plugins folder

According to the Cypress website, a plugin is "a way to support and extend the behavior of Cypress". And this is what is expected to be in this folder, anything that can extend the behavior of the tester.

### Support folder

This folder is the place for all the utilities that the tests are going to need and it is split into multiple folders so the code is more maintainable. In the following points we will explain each of them:

* **Commands folder**: Contains all the commands added to cypress to enhance its functionality. They are separated into folders related to what the commands are about.
  
* **Common folder**: Contains all the code that is going to be used under the tests and that is repeated as it is needed for Oneadmin context and User context.

* **Models folder**: Contains the classes to manage OpenNebula resources.

* **Utils folder**: Contains all the utilities needed to help in the development.
  
## Test development

The test must be programmed to use two contexts: `Oneadmin` and `User`, meaning that the structure of the tests should be as the following code:

```js
import { adminContext, userContext } from '@utils/constants'
import {
  ...
} from '@common/...'

// Imports and tests local constants
...

describe('Sunstone GUI ...', function () {
  context('User', userContext, function () {
    // Tests actions such as: before, beforeEach, it, after, afterEach
    ...

    it('should ...', function () {
      // Call to function in @common/*
    })

  })

  context('Oneadmin', adminContext, function () {
    ...
  })
```

The code shown above will be located in the `integration` folder.

As the functionality to test will be the same for both contexts but with different uses, to avoid code duplication the content of the tests will be inside the `@common` (`cypress/support/common/`) folder, and it will also be imported at the beginning of the tests.

These two folders should be enough to develop FireEdge Sunstone testing, but if you need to create more functionality please refer to [Folder structure](#folder-structure) section

### Robust test development

In order to make the most of our test reports we need to build robust tests that provide us with the most consistent results possible. To do that we take the following approach to test development:

1. Tests should be indenepdent
    - Each test should be self-contained and not rely on external resources or other tests to run successfully. This will help prevent cascading failures and make our tests more   
robust.
2. Track and manage resources
    - Identify all the resources required for each test, such as virtual machines, hosts, and other dependencies. Create these resources automatically when the test starts, and clean them up afterwards. This will ensure that tests don't interfere with one another and leave behind unwanted stuff.
3. Implement retry-ability
    - Our tests should be designed to handle unexpected failures gracefully. We can achieve this by introducing retry mechanisms that allow tests to recover from transient errors and network glitches etc... This means that the individual test cases should be designed in a way so that they can be re-run in case they fail due to environmental errors etc...

So to help with adhering to these guidelines when developing tests, the following cleanup command has been created and should be used *vigorously* throughout the test development. 

***cy.cleanup()***

 which cleans up the following resources when called:
- Templates
- Vms
- Datastores
- Hosts
- Clusters
- Groups
- Images
- Secgroups
- Users
- Vnets

This will clean up `everything` by default, however it will respect the `protected resources` found in `cypress/fixtures/cleanup/protected.json` so here we can specify items that should never be cleaned up, like the system datastore etc...

*cypress/fixtures/cleanup/protected.json*
```
{
  "datastores": {
    "NAMES": ["system", "default", "files"]
  },
  "users": {
    "NAMES": ["oneadmin", "serveradmin", "user"]
  },
  "groups": {
    "NAMES": ["oneadmin","users"]
  },
  "secgroups": {
    "IDS": ["0"]
  },
  "clusters": {
    "IDS": ["0","100"]
  }
}
```

Resources are specifiable by both `NAME` and `ID`, this makes it possible to protect a future resource for example from being deleted if you know the name it's going to be created under or the `ID` ( but since the `ID` is always incremented it might be a lot more difficult to determine).

### Extended use cases

It is also possible to define filtering options on a case to case basis, if for example you only wanted to clean up certain resources at some point you could define them exactly using the optional objects parameter:
```
      cy.cleanup({
        groups: { NAMES: ['users'] },
        users: { NAMES: ['cleanup'], IDS: ['12'] },
        datastores: { NAMES: ['system'] },
      })
```
So when used like this it would filter out the cleanup options for the following three objects:
- `groups`
- `users`
- `datastores`

So in this example it will only filter by the options specified. If for example the `users` group is not found then nothing will be filtered/cleaned up from the groups object. But it still defaults to cleaning up everything for every other object/resource if nothing else has been specified.

_**This also respects the `protected resources`**_

So even though the system datastore was explicitly stated as to be cleaned up in that call it won't be because it is marked as a `protected resource` in the [configuration file](https://github.com/OpenNebula/development/blob/master/readiness/spec/fireedge/cypress/fixtures/cleanup/protected.json).

## NOTE

**This simply adds the cleanup functionality and or utility to the test suite. The test cases have not been adapted to make full use of this functionality so it has not been implemented in any test files yet.**

