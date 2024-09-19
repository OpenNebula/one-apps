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
import static org.junit.Assert.assertTrue;

import org.junit.After;
import org.junit.AfterClass;
import org.junit.Before;
import org.junit.BeforeClass;
import org.junit.Test;
import org.opennebula.client.Client;
import org.opennebula.client.OneResponse;
import org.opennebula.client.group.Group;
import org.opennebula.client.vntemplate.*;
import org.opennebula.client.user.User;
import org.opennebula.client.vnet.VirtualNetwork;

public class VNTemplateTest
{

    private static VirtualNetworkTemplate vntemplate;
    private static VirtualNetworkTemplatePool vntemplatePool;

    private static Client client;

    private static OneResponse res;
    private static String name = "new_test_vntemplate";


    private static String vntemplate_str =
        "NAME = \"" + name + "\"\n" +
        "VN_MAD=bridge\n" +
        "ATT1 = \"VAL1\"\n" +
        "ATT2 = \"VAL2\"";

    /**
     * @throws java.lang.Exception
     */
    @BeforeClass
    public static void setUpBeforeClass() throws Exception
    {
        client          = new Client();
        vntemplatePool    = new VirtualNetworkTemplatePool(client);
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
        res = VirtualNetworkTemplate.allocate(client, vntemplate_str);

        int oid = res.isError() ? -1 : Integer.parseInt(res.getMessage());
        vntemplate = new VirtualNetworkTemplate(oid, client);
    }

    /**
     * @throws java.lang.Exception
     */
    @After
    public void tearDown() throws Exception
    {
        vntemplate.delete();
    }

    @Test
    public void allocate()
    {
        vntemplate.delete();

        res = VirtualNetworkTemplate.allocate(client, vntemplate_str);
        assertTrue( res.getErrorMessage(), !res.isError() );

        int oid = res.isError() ? -1 : Integer.parseInt(res.getMessage());
        vntemplate = new VirtualNetworkTemplate(oid, client);


        vntemplatePool.info();

        boolean found = false;
        for(VirtualNetworkTemplate temp : vntemplatePool)
        {
            found = found || temp.getName().equals(name);
        }

        assertTrue( found );
    }

    @Test
    public void info()
    {
        res = vntemplate.info();
        assertTrue( res.getErrorMessage(), !res.isError() );
        assertTrue( vntemplate.getName().equals(name) );
    }

    @Test
    public void update()
    {
        res = vntemplate.info();
        assertTrue( res.getErrorMessage(), !res.isError() );

        assertTrue( vntemplate.xpath("TEMPLATE/ATT1").equals( "VAL1" ) );
        assertTrue( vntemplate.xpath("TEMPLATE/ATT2").equals( "VAL2" ) );

        String new_template =   "ATT2 = NEW_VAL\n" +
                                "ATT3 = VAL3";

        res = vntemplate.update(new_template);
        assertTrue( res.getErrorMessage(), !res.isError() );


        res = vntemplate.info();
        assertTrue( res.getErrorMessage(), !res.isError() );
        assertTrue( vntemplate.xpath("TEMPLATE/ATT1").equals( "" ) );
        assertTrue( vntemplate.xpath("TEMPLATE/ATT2").equals( "NEW_VAL" ) );
        assertTrue( vntemplate.xpath("TEMPLATE/ATT3").equals( "VAL3" ) );
    }

    @Test
    public void publish()
    {
        res = vntemplate.publish();
        assertTrue( res.getErrorMessage(), !res.isError() );

        vntemplate.info();
        assertTrue( vntemplate.xpath("PERMISSIONS/GROUP_U").equals("1") );
    }

    @Test
    public void unpublish()
    {
        res = vntemplate.unpublish();
        assertTrue( res.getErrorMessage(), !res.isError() );

        vntemplate.info();
        assertTrue( vntemplate.xpath("PERMISSIONS/GROUP_U").equals("0") );
    }

    @Test
    public void chmod()
    {
        res = vntemplate.info();
        assertTrue( res.getErrorMessage(), !res.isError() );

        String owner_a = vntemplate.xpath("PERMISSIONS/OWNER_A");
        String group_a = vntemplate.xpath("PERMISSIONS/GROUP_A");

        res = vntemplate.chmod(0, 1, -1, 1, 0, -1, 1, 1, 0);
        assertTrue( res.getErrorMessage(), !res.isError() );

        res = vntemplate.info();
        assertTrue( res.getErrorMessage(), !res.isError() );

        assertTrue( vntemplate.xpath("PERMISSIONS/OWNER_U").equals("0") );
        assertTrue( vntemplate.xpath("PERMISSIONS/OWNER_M").equals("1") );
        assertTrue( vntemplate.xpath("PERMISSIONS/OWNER_A").equals(owner_a) );
        assertTrue( vntemplate.xpath("PERMISSIONS/GROUP_U").equals("1") );
        assertTrue( vntemplate.xpath("PERMISSIONS/GROUP_M").equals("0") );
        assertTrue( vntemplate.xpath("PERMISSIONS/GROUP_A").equals(group_a) );
        assertTrue( vntemplate.xpath("PERMISSIONS/OTHER_U").equals("1") );
        assertTrue( vntemplate.xpath("PERMISSIONS/OTHER_M").equals("1") );
        assertTrue( vntemplate.xpath("PERMISSIONS/OTHER_A").equals("0") );
    }

    @Test
    public void chmod_octet()
    {
        res = vntemplate.info();
        assertTrue( res.getErrorMessage(), !res.isError() );

        res = vntemplate.chmod(640);
        assertTrue( res.getErrorMessage(), !res.isError() );

        res = vntemplate.info();
        assertTrue( res.getErrorMessage(), !res.isError() );

        assertTrue( vntemplate.xpath("PERMISSIONS/OWNER_U").equals("1") );
        assertTrue( vntemplate.xpath("PERMISSIONS/OWNER_M").equals("1") );
        assertTrue( vntemplate.xpath("PERMISSIONS/OWNER_A").equals("0") );
        assertTrue( vntemplate.xpath("PERMISSIONS/GROUP_U").equals("1") );
        assertTrue( vntemplate.xpath("PERMISSIONS/GROUP_M").equals("0") );
        assertTrue( vntemplate.xpath("PERMISSIONS/GROUP_A").equals("0") );
        assertTrue( vntemplate.xpath("PERMISSIONS/OTHER_U").equals("0") );
        assertTrue( vntemplate.xpath("PERMISSIONS/OTHER_M").equals("0") );
        assertTrue( vntemplate.xpath("PERMISSIONS/OTHER_A").equals("0") );

        res = vntemplate.chmod("147");
        assertTrue( res.getErrorMessage(), !res.isError() );

        res = vntemplate.info();
        assertTrue( res.getErrorMessage(), !res.isError() );

        assertTrue( vntemplate.xpath("PERMISSIONS/OWNER_U").equals("0") );
        assertTrue( vntemplate.xpath("PERMISSIONS/OWNER_M").equals("0") );
        assertTrue( vntemplate.xpath("PERMISSIONS/OWNER_A").equals("1") );
        assertTrue( vntemplate.xpath("PERMISSIONS/GROUP_U").equals("1") );
        assertTrue( vntemplate.xpath("PERMISSIONS/GROUP_M").equals("0") );
        assertTrue( vntemplate.xpath("PERMISSIONS/GROUP_A").equals("0") );
        assertTrue( vntemplate.xpath("PERMISSIONS/OTHER_U").equals("1") );
        assertTrue( vntemplate.xpath("PERMISSIONS/OTHER_M").equals("1") );
        assertTrue( vntemplate.xpath("PERMISSIONS/OTHER_A").equals("1") );
    }

    @Test
    public void attributes()
    {
        res = vntemplate.info();
        assertTrue( res.getErrorMessage(), !res.isError() );
        assertTrue( vntemplate.xpath("NAME").equals(name) );
    }

    @Test
    public void delete()
    {
        res = vntemplate.delete();
        assertTrue( res.getErrorMessage(), !res.isError() );

        res = vntemplate.info();
        assertTrue( res.isError() );
    }

    @Test
    public void chown()
    {
        // Create a new User and Group
        res = User.allocate(client, "vntemplate_test_user", "password");
        assertTrue( res.getErrorMessage(), !res.isError() );

        int uid = Integer.parseInt(res.getMessage());

        res = Group.allocate(client, "vntemplate_test_group");
        assertTrue( res.getErrorMessage(), !res.isError() );

        int gid = Integer.parseInt(res.getMessage());

        res = vntemplate.info();
        assertTrue( res.getErrorMessage(), !res.isError() );

        assertTrue( vntemplate.uid() == 0 );
        assertTrue( vntemplate.gid() == 0 );

        res = vntemplate.chown(uid, gid);
        assertTrue( res.getErrorMessage(), !res.isError() );

        res = vntemplate.info();
        assertTrue( res.getErrorMessage(), !res.isError() );

        assertTrue( vntemplate.uid() == uid );
        assertTrue( vntemplate.gid() == gid );

        res = vntemplate.chgrp(0);

        res = vntemplate.info();
        assertTrue( res.getErrorMessage(), !res.isError() );

        assertTrue( vntemplate.uid() == uid );
        assertTrue( vntemplate.gid() == 0 );
    }

    @Test
    public void instantiate() throws Exception
    {
        res = vntemplate.instantiate("new_vm_name");
        assertTrue( res.getErrorMessage(), !res.isError() );

        res = User.allocate(client, "test_user", "test_pass");

        assertTrue( res.getErrorMessage(), !res.isError() );

        Client oneClient = new Client("test_user:test_pass","http://localhost:2633/RPC2");

        int user_id = Integer.parseInt(res.getMessage());

        res = vntemplate.chown(user_id, 0);
        assertTrue( res.getErrorMessage(), !res.isError() );

        res = vntemplate.instantiate(oneClient, vntemplate.id(), "new_vnet_name", "ATT = 3");
        assertTrue( res.getErrorMessage(), !res.isError() );

        int vnet_id = Integer.parseInt(res.getMessage());
        VirtualNetwork vnet = new VirtualNetwork(vnet_id, client);

        res = vnet.info();
        assertTrue( res.getErrorMessage(), !res.isError() );

        assertTrue( vnet.getName().equals( "new_vnet_name" ) );
    }
}
