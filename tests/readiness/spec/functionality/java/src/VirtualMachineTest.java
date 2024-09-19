/*******************************************************************************
 * Copyright 2002-2022, OpenNebula Project, OpenNebula Systems
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 ******************************************************************************/
import static org.junit.Assert.*;

import org.junit.After;
import org.junit.AfterClass;
import org.junit.Before;
import org.junit.BeforeClass;
import org.junit.Test;
import org.opennebula.client.Client;
import org.opennebula.client.OneResponse;
import org.opennebula.client.datastore.Datastore;
import org.opennebula.client.host.Host;
import org.opennebula.client.image.Image;
import org.opennebula.client.vm.VirtualMachine;
import org.opennebula.client.vm.VirtualMachinePool;
import org.opennebula.client.vnet.VirtualNetwork;
import org.opennebula.client.vnet.VirtualNetworkPool;
import org.opennebula.client.secgroup.*;


public class VirtualMachineTest
{

    private static VirtualMachine vm;
    private static VirtualMachinePool vmPool;

    private static Client client;

    private static int hid_A, hid_B, vnid, sgid;

    private static OneResponse res;
    private static String name = "new_test_machine";

    private static String template_vn = "NAME = vn_test_sg\n"+
        "BRIDGE = vbr0\n" +
        "VN_MAD = dummy\n" +
        "NETWORK_ADDRESS = 192.168.0.0\n"+
        "AR = [ TYPE = IP4, IP = 192.168.0.1, SIZE = 254 ]\n";

    private static String template_sg = "NAME = sg_nic_attach\n" +
        "DESCRIPTION  = \"test security group\"\n"+
        "ATT1 = \"VAL1\"\n";

    private static String template_backup_ds = "NAME = backup_ds\n" +
        "DS_MAD=dummy\n" +
        "TM_MAD=-\n" +
        "TYPE=BACKUP_DS\n";

    /**
     *  Wait until the VM changes to the specified state.
     *  There is a time-out of 10 seconds.
     */
    void waitAssert(VirtualMachine vm, String state, String lcmState)
    {
        int n_steps     = 100;
        int step        = 100;

        int i = 0;

        vm.info();

        while( !( (vm.stateStr().equals(state) && (!state.equals("ACTIVE") || vm.lcmStateStr().equals(lcmState) ))|| i > n_steps ))
        {
            try{ Thread.sleep(step); } catch (Exception e){}

            vm.info();
            i++;
        }

        assertTrue( vm.stateStr().equals(state) );
        if(state.equals("ACTIVE"))
        {
            assertTrue( vm.lcmStateStr().equals(lcmState) );
        }
    }

    /**
     * @throws java.lang.Exception
     */
    @BeforeClass
    public static void setUpBeforeClass() throws Exception
    {
        client      = new Client();
        vmPool      = new VirtualMachinePool(client);
        VirtualNetworkPool vnetPool = new VirtualNetworkPool(client);
        SecurityGroupPool sgpool = new SecurityGroupPool(client);


        res = Host.allocate(client, "host_A",
                            "dummy", "dummy");
        hid_A = Integer.parseInt( res.getMessage() );

        res = Host.allocate(client, "host_B",
                            "dummy", "dummy");
        hid_B = Integer.parseInt( res.getMessage() );

        Datastore systemDs = new Datastore(0, client);
        systemDs.update("TM_MAD = dummy");

        res = VirtualNetwork.allocate(client, template_vn);
        vnid = !res.isError() ? Integer.parseInt(res.getMessage()) : -1;

        res = SecurityGroup.allocate(client, template_sg);
        sgid = res.isError() ? -1 : Integer.parseInt(res.getMessage());
    }

    /**
     * @throws java.lang.Exception
     */
    @AfterClass
    public static void tearDownAfterClass() throws Exception
    {
    }

    /**
     * @throws java.lang.Exception
     */
    @Before
    public void setUp() throws Exception
    {
        String template = "NAME = " + name + "\n"+
                          "MEMORY = 512\n" +
                          "CPU = 1\n" +
                          "CONTEXT = [DNS = 192.169.1.4]";

        res = VirtualMachine.allocate(client, template);
        int vmid = !res.isError() ? Integer.parseInt(res.getMessage()) : -1;

        vm = new VirtualMachine(vmid, client);
    }

    /**
     * @throws java.lang.Exception
     */
    @After
    public void tearDown() throws Exception
    {
        vm.recover(3);
        waitAssert(vm, "DONE", "-");

        vm = null;
    }

    @Test
    public void allocate()
    {
        res = vmPool.info();
        assertTrue( res.getErrorMessage(), !res.isError() );

        boolean found = false;
        for(VirtualMachine vm : vmPool)
        {
            found = found || vm.getName().equals(name);
        }

        assertTrue( found );
    }

    @Test
    public void update()
    {
        res = vm.info();
        assertTrue( res.getErrorMessage(), !res.isError() );

        assertTrue( vm.getName().equals(name) );
    }

    @Test
    public void hold()
    {
        res = vm.hold();
        assertTrue( res.getErrorMessage(), !res.isError() );
        waitAssert(vm, "HOLD", "-");
    }

    @Test
    public void release()
    {
        vm.hold();

        res = vm.release();
        assertTrue( res.getErrorMessage(), !res.isError() );
        waitAssert(vm, "PENDING", "-");
    }

    @Test
    public void deploy()
    {
        res = vm.deploy(hid_A);
        assertTrue( res.getErrorMessage(), !res.isError() );
        waitAssert(vm, "ACTIVE", "RUNNING");
    }

    @Test
    public void migrate()
    {
        vm.deploy(hid_A);
        waitAssert(vm, "ACTIVE", "RUNNING");

        res = vm.migrate(hid_B);
        assertTrue( res.getErrorMessage(), !res.isError() );
        waitAssert(vm, "ACTIVE", "RUNNING");
    }

    @Test
    public void liveMigrate()
    {
        vm.deploy(hid_A);
        waitAssert(vm, "ACTIVE", "RUNNING");

        res = vm.migrate(hid_B, true);
        assertTrue( res.getErrorMessage(), !res.isError() );
        waitAssert(vm, "ACTIVE", "RUNNING");
    }

    @Test
    public void terminate()
    {
        vm.deploy(hid_A);
        waitAssert(vm, "ACTIVE", "RUNNING");

        res = vm.terminate();
        assertTrue( res.getErrorMessage(), !res.isError() );
        waitAssert(vm, "DONE", "-");
    }

    @Test
    public void terminatehard()
    {
        vm.deploy(hid_A);
        waitAssert(vm, "ACTIVE", "RUNNING");

        res = vm.terminate(true);
        assertTrue( res.getErrorMessage(), !res.isError() );
        waitAssert(vm, "DONE", "-");
    }

    @Test
    public void stop()
    {
        vm.deploy(hid_A);
        waitAssert(vm, "ACTIVE", "RUNNING");

        res = vm.stop();
        assertTrue( res.getErrorMessage(), !res.isError() );
        waitAssert(vm, "STOPPED", "-");
    }

    @Test
    public void suspend()
    {
        vm.deploy(hid_A);
        waitAssert(vm, "ACTIVE", "RUNNING");

        res = vm.suspend();
        assertTrue( res.getErrorMessage(), !res.isError() );
        waitAssert(vm, "SUSPENDED", "-");
    }

    @Test
    public void resume()
    {
        vm.deploy(hid_A);
        waitAssert(vm, "ACTIVE", "RUNNING");

        vm.suspend();
        waitAssert(vm, "SUSPENDED", "-");

        res = vm.resume();
        assertTrue( res.getErrorMessage(), !res.isError() );
        waitAssert(vm, "ACTIVE", "RUNNING");
    }

    @Test
    public void delete()
    {
        vm.deploy(hid_A);
        waitAssert(vm, "ACTIVE", "RUNNING");
        res = vm.recover(3);

        assertTrue( res.getErrorMessage(), !res.isError() );
        waitAssert(vm, "DONE", "-");
    }

    @Test
    public void restart()
    {
        // TODO
    }

    @Test
    public void deleteRecreate()
    {
        vm.deploy(hid_A);
        waitAssert(vm, "ACTIVE", "RUNNING");
        res = vm.recover(4);

        assertTrue( res.getErrorMessage(), !res.isError() );
        waitAssert(vm, "PENDING", "-");
    }

    @Test
    public void attributes()
    {
        res = vm.info();
        assertTrue( res.getErrorMessage(), !res.isError() );

        assertTrue( vm.xpath("NAME").equals(name) );
        assertTrue( vm.xpath("TEMPLATE/MEMORY").equals("512") );
//        assertTrue( vm.xpath("ID").equals("0") );
        assertTrue( vm.xpath("TEMPLATE/MEMORY").equals("512") );
        assertTrue( vm.xpath("TEMPLATE/CONTEXT/DNS").equals("192.169.1.4") );
    }

    @Test
    public void schedActions()
    {
        // Create sched action
        String template = "SCHED_ACTION = [\n" +
                "ACTION = poweroff-hard," +
                "TIME = 123456789 ]";

        res = vm.schedadd(template);
        assertTrue( res.getErrorMessage(), !res.isError() );

        res = vm.info();
        assertTrue( res.getErrorMessage(), !res.isError() );
        assertTrue( vm.xpath("TEMPLATE/SCHED_ACTION/ACTION").equals("poweroff-hard") );

        // Update sched action
        String template_update = "SCHED_ACTION = [\n" +
                "ACTION = poweroff," +
                "TIME = 123456789 ]";

        res = vm.schedupdate(0, template_update);
        assertTrue( res.getErrorMessage(), !res.isError() );

        res = vm.info();
        assertTrue( res.getErrorMessage(), !res.isError() );
        assertTrue( vm.xpath("TEMPLATE/SCHED_ACTION/ACTION").equals("poweroff") );

        // Delete sched action
        res = vm.scheddelete(0);
        assertTrue( res.getErrorMessage(), !res.isError() );

        res = vm.info();
        assertTrue( res.getErrorMessage(), !res.isError() );
        assertTrue( vm.xpath("TEMPLATE/SCHED_ACTION").isEmpty() );
    }

    @Test
    public void lock()
    {
        res = vm.lock(1);
        assertTrue( res.getErrorMessage(), !res.isError() );

        res = vm.info();
        assertTrue( res.getErrorMessage(), !res.isError() );
        assertTrue( vm.xpath("LOCK/LOCKED").equals("1") );

        res = vm.unlock();
        assertTrue( res.getErrorMessage(), !res.isError() );

        res = vm.info();
        assertTrue( res.getErrorMessage(), !res.isError() );
        assertTrue( vm.xpath("LOCK").isEmpty() );
    }

    // TODO
/*
    @Test
    public void savedisk()
    {
        String img_template =
                "NAME = \"test_img\"\n" +
                "PATH = /etc/hosts\n" +
                "ATT1 = \"VAL1\"\n" +
                "ATT2 = \"VAL2\"";

        res = Image.allocate(client, img_template, 1);
        assertTrue( res.getErrorMessage(), !res.isError() );

        int imgid = Integer.parseInt(res.getMessage());

        Image img = new Image(imgid, client);
        ImageTest.waitAssert(img, "READY");


        String template = "NAME = savedisk_vm\n"+
                          "MEMORY = 512\n" +
                          "CPU = 1\n" +
                          "CONTEXT = [DNS = 192.169.1.4]\n" +
                          "DISK = [ IMAGE = test_img ]";

        res = VirtualMachine.allocate(client, template);
        assertTrue( res.getErrorMessage(), !res.isError() );

        int vmid = !res.isError() ? Integer.parseInt(res.getMessage()) : -1;

        vm = new VirtualMachine(vmid, client);

        res = vm.deploy(hid_A);
        assertTrue( res.getErrorMessage(), !res.isError() );

        waitAssert(vm, "ACTIVE", "RUNNING");

        res = vm.savedisk(0, "New_image");
        assertTrue( res.getErrorMessage(), !res.isError() );

        int new_imgid = Integer.parseInt(res.getMessage());
        assertTrue( new_imgid == imgid+1 );

        res = vm.info();
        assertTrue( res.getErrorMessage(), !res.isError() );
    }
*/
    @Test
    public void resize()
    {
        res = vm.resize("CPU = 2.5\nMEMORY = 512\nVCPU = 0", true);
        assertTrue( res.getErrorMessage(), !res.isError() );

        res = vm.resize("CPU = 1\nMEMORY = 128\nVCPU = 2", false);
        assertTrue( res.getErrorMessage(), !res.isError() );
    }

    @Test
    public void accounting()
    {
        res = vmPool.accounting(-2, -1, -1);
        assertTrue( res.getErrorMessage(), !res.isError() );
    }

    @Test
    public void showback()
    {
        res = vmPool.calculateshowback(-2, -1, -1, -1, -1);
        assertTrue( res.getErrorMessage(), !res.isError() );

        res = vmPool.showback(-2, -1, -1, -1, -1);
        assertTrue( res.getErrorMessage(), !res.isError() );
    }

    @Test
    public void nicAttachDetachattachSgNic()
    {
        vm.deploy(hid_A);
        waitAssert(vm, "ACTIVE", "RUNNING");

        // Attach NIC
        res = vm.nicAttach("NIC = [ NETWORK_ID = " + vnid + " ]");
        assertTrue( res.getErrorMessage(), !res.isError() );
        waitAssert(vm, "ACTIVE", "RUNNING");

        // Update NIC
        res = vm.nicUpdate(0, "NIC = [ INBOUND_AVG_BW = 111 ]", true);
        assertTrue( res.getErrorMessage(), !res.isError() );
        waitAssert(vm, "ACTIVE", "RUNNING");

        assertTrue( vm.xpath("TEMPLATE/NIC/INBOUND_AVG_BW").equals("111") );

        // Attach SG
        res = vm.sgAttach(0, sgid);
        assertTrue( res.getErrorMessage(), !res.isError() );
        waitAssert(vm, "ACTIVE", "RUNNING");

        assertTrue( vm.xpath("TEMPLATE/NIC/SECURITY_GROUPS").contains(Integer.toString(sgid)) );

        // Detach SG
        res = vm.sgDetach(0, sgid);
        assertTrue( res.getErrorMessage(), !res.isError() );
        waitAssert(vm, "ACTIVE", "RUNNING");

        assertFalse( vm.xpath("TEMPLATE/NIC/SECURITY_GROUPS").contains(Integer.toString(sgid)) );

        // Detach NIC
        res = vm.nicDetach(0);
        assertTrue( res.getErrorMessage(), !res.isError() );
        waitAssert(vm, "ACTIVE", "RUNNING");
    }

    @Test
    public void pciAttachDetach()
    {
        vm.deploy(hid_A);
        waitAssert(vm, "ACTIVE", "RUNNING");

        vm.poweroff();
        waitAssert(vm, "POWEROFF", "");

        // Attach PCI
        res = vm.pciAttach("PCI = [ DEVICE = 0863 ]");
        assertTrue( res.getErrorMessage(), !res.isError() );

        vm.info();
        assertTrue( vm.xpath("TEMPLATE/PCI/DEVICE").equals("0863") );

        // Dettach PCI
        res = vm.pciDetach(0);
        assertTrue( res.getErrorMessage(), !res.isError() );

        vm.info();
        assertTrue( vm.xpath("TEMPLATE/PCI").isEmpty() );
    }

    @Test
    public void backup()
    {
        vm.deploy(hid_A);
        waitAssert(vm, "ACTIVE", "RUNNING");

        res = Datastore.allocate(client, template_backup_ds, 0);

        assertTrue( res.getErrorMessage(), !res.isError() );

        int backup_ds = Integer.parseInt( res.getMessage() );

        res = vm.backup(backup_ds, false);
        assertTrue( res.getErrorMessage(), !res.isError() );
        waitAssert(vm, "ACTIVE", "RUNNING");

        // Inplace restore VM disks
        vm.poweroff();
        waitAssert(vm, "POWEROFF", "");

        vm.info();
        int backupId = Integer.parseInt(vm.xpath("BACKUPS/BACKUP_IDS/ID"));

        res = vm.restore(backupId, -1, -1);
        assertTrue( res.getErrorMessage(), !res.isError() );
    }
}
