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
import org.opennebula.client.backupjob.*;
import org.opennebula.client.user.User;

public class BackupJobTest
{

    private static BackupJob bj;
    private static BackupJobPool pool;

    private static Client client;

    private static OneResponse res;
    private static String name = "new_test_bj";

    private static String template_str =
        "NAME = \"" + name + "\"\n" +
        "BACKUP_VMS  = \"0,2,4\"\n";

    /**
     * @throws java.lang.Exception
     */
    @BeforeClass
    public static void setUpBeforeClass() throws Exception
    {
        client  = new Client();
        pool    = new BackupJobPool(client);
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
        res = BackupJob.allocate(client, template_str);

        int oid = res.isError() ? -1 : Integer.parseInt(res.getMessage());
        bj = new BackupJob(oid, client);
    }

    /**
     * @throws java.lang.Exception
     */
    @After
    public void tearDown() throws Exception
    {
        bj.delete();
    }

    @Test
    public void allocate()
    {
        pool.info();

        boolean found = false;
        for(BackupJob temp : pool)
        {
            found = found || temp.getName().equals(name);
        }

        assertTrue( found );
    }

    @Test
    public void info()
    {
        res = bj.info();
        assertTrue( res.getErrorMessage(), !res.isError() );

        assertTrue( bj.getName().equals(name) );
    }

    @Test
    public void update()
    {
        res = bj.info();
        assertTrue( res.getErrorMessage(), !res.isError() );

        assertTrue( bj.xpath("TEMPLATE/BACKUP_VMS").equals( "0,2,4" ) );

        String new_bj = "KEEP_LAST = 5";

        res = bj.update(new_bj, true);
        assertTrue( res.getErrorMessage(), !res.isError() );

        res = bj.info();
        assertTrue( res.getErrorMessage(), !res.isError() );
        assertTrue( bj.xpath("TEMPLATE/BACKUP_VMS").equals( "0,2,4" ) );
        assertTrue( bj.xpath("TEMPLATE/KEEP_LAST").equals( "5" ) );
    }

    @Test
    public void rename()
    {
        res = bj.info();
        assertTrue( res.getErrorMessage(), !res.isError() );

        assertTrue( bj.xpath("NAME").equals( name ) );

        res = bj.rename("new_name");
        assertTrue( res.getErrorMessage(), !res.isError() );

        res = bj.info();
        assertTrue( res.getErrorMessage(), !res.isError() );
        assertTrue( bj.xpath("NAME").equals( "new_name" ) );
    }

    @Test
    public void chown()
    {
        // Create a new User and Group
        res = User.allocate(client, "bj_test_user", "password");
        assertTrue( res.getErrorMessage(), !res.isError() );

        int uid = Integer.parseInt(res.getMessage());

        res = Group.allocate(client, "bj_test_group");
        assertTrue( res.getErrorMessage(), !res.isError() );

        int gid = Integer.parseInt(res.getMessage());

        res = bj.info();
        assertTrue( res.getErrorMessage(), !res.isError() );

        assertTrue( bj.uid() == 0 );
        assertTrue( bj.gid() == 0 );

        res = bj.chown(uid, gid);
        assertTrue( res.getErrorMessage(), !res.isError() );

        res = bj.info();
        assertTrue( res.getErrorMessage(), !res.isError() );

        assertTrue( bj.uid() == uid );
        assertTrue( bj.gid() == gid );

        res = bj.chgrp(0);

        res = bj.info();
        assertTrue( res.getErrorMessage(), !res.isError() );

        assertTrue( bj.uid() == uid );
        assertTrue( bj.gid() == 0 );
    }

    @Test
    public void chmod()
    {
        res = bj.info();
        assertTrue( res.getErrorMessage(), !res.isError() );

        String owner_a = bj.xpath("PERMISSIONS/OWNER_A");
        String group_a = bj.xpath("PERMISSIONS/GROUP_A");

        res = bj.chmod(0, 1, -1, 1, 0, -1, 1, 1, 0);
        assertTrue( res.getErrorMessage(), !res.isError() );

        res = bj.info();
        assertTrue( res.getErrorMessage(), !res.isError() );

        assertTrue( bj.xpath("PERMISSIONS/OWNER_U").equals("0") );
        assertTrue( bj.xpath("PERMISSIONS/OWNER_M").equals("1") );
        assertTrue( bj.xpath("PERMISSIONS/OWNER_A").equals(owner_a) );
        assertTrue( bj.xpath("PERMISSIONS/GROUP_U").equals("1") );
        assertTrue( bj.xpath("PERMISSIONS/GROUP_M").equals("0") );
        assertTrue( bj.xpath("PERMISSIONS/GROUP_A").equals(group_a) );
        assertTrue( bj.xpath("PERMISSIONS/OTHER_U").equals("1") );
        assertTrue( bj.xpath("PERMISSIONS/OTHER_M").equals("1") );
        assertTrue( bj.xpath("PERMISSIONS/OTHER_A").equals("0") );
    }

    @Test
    public void chmod_octet()
    {
        res = bj.info();
        assertTrue( res.getErrorMessage(), !res.isError() );

        res = bj.chmod(640);
        assertTrue( res.getErrorMessage(), !res.isError() );

        res = bj.info();
        assertTrue( res.getErrorMessage(), !res.isError() );

        assertTrue( bj.xpath("PERMISSIONS/OWNER_U").equals("1") );
        assertTrue( bj.xpath("PERMISSIONS/OWNER_M").equals("1") );
        assertTrue( bj.xpath("PERMISSIONS/OWNER_A").equals("0") );
        assertTrue( bj.xpath("PERMISSIONS/GROUP_U").equals("1") );
        assertTrue( bj.xpath("PERMISSIONS/GROUP_M").equals("0") );
        assertTrue( bj.xpath("PERMISSIONS/GROUP_A").equals("0") );
        assertTrue( bj.xpath("PERMISSIONS/OTHER_U").equals("0") );
        assertTrue( bj.xpath("PERMISSIONS/OTHER_M").equals("0") );
        assertTrue( bj.xpath("PERMISSIONS/OTHER_A").equals("0") );

        res = bj.chmod("147");
        assertTrue( res.getErrorMessage(), !res.isError() );

        res = bj.info();
        assertTrue( res.getErrorMessage(), !res.isError() );

        assertTrue( bj.xpath("PERMISSIONS/OWNER_U").equals("0") );
        assertTrue( bj.xpath("PERMISSIONS/OWNER_M").equals("0") );
        assertTrue( bj.xpath("PERMISSIONS/OWNER_A").equals("1") );
        assertTrue( bj.xpath("PERMISSIONS/GROUP_U").equals("1") );
        assertTrue( bj.xpath("PERMISSIONS/GROUP_M").equals("0") );
        assertTrue( bj.xpath("PERMISSIONS/GROUP_A").equals("0") );
        assertTrue( bj.xpath("PERMISSIONS/OTHER_U").equals("1") );
        assertTrue( bj.xpath("PERMISSIONS/OTHER_M").equals("1") );
        assertTrue( bj.xpath("PERMISSIONS/OTHER_A").equals("1") );
    }

    @Test
    public void delete()
    {
        res = bj.delete();
        assertTrue( res.getErrorMessage(), !res.isError() );

        res = bj.info();
        assertTrue( res.isError() );
    }

    @Test
    public void lock()
    {
        res = bj.lock(1);
        assertTrue( res.getErrorMessage(), !res.isError() );

        res = bj.info();
        assertTrue( bj.xpath("LOCK/LOCKED").equals("1") );

        res = bj.unlock();
        assertTrue( res.getErrorMessage(), !res.isError() );

        res = bj.info();
        assertTrue( bj.xpath("LOCK").isEmpty() );
    }

    @Test
    public void backup()
    {
        // Only test the call exists, do not check any values
        res = bj.backup();
        assertTrue( res.getErrorMessage(), !res.isError() );
    }

    @Test
    public void cancel()
    {
        // Only test the call exists, do not check any values
        res = bj.cancel();
        assertTrue( res.getErrorMessage(), !res.isError() );
    }

    @Test
    public void retry()
    {
        // Only test the call exists, do not check any values
        res = bj.backup();
        assertTrue( res.getErrorMessage(), !res.isError() );
    }

    @Test
    public void priority()
    {
        res = bj.priority(15);
        assertTrue( res.getErrorMessage(), !res.isError() );

        bj.info();

        assertTrue( bj.xpath("PRIORITY").equals("15") );
    }

    @Test
    public void scheduled_actions()
    {
        String template_sa = "SCHED_ACTION = [ " +
              "REPEAT=\"3\"," +
              "DAYS=\"1\"," +
              "TIME=\"1695478500\" ]";

        res = bj.schedadd(template_sa);
        assertTrue( res.getErrorMessage(), !res.isError() );

        bj.info();

        int sa_id = Integer.parseInt(bj.xpath("TEMPLATE/SCHED_ACTION/ID"));
        assertTrue( bj.xpath("TEMPLATE/SCHED_ACTION/REPEAT").equals("3") );
        assertTrue( bj.xpath("TEMPLATE/SCHED_ACTION/DAYS").equals("1") );

        String update_sa = "SCHED_ACTION = [ DAYS=\"5\" ]";

        res = bj.schedupdate(sa_id, update_sa);
        assertTrue( res.getErrorMessage(), !res.isError() );

        bj.info();

        assertTrue( bj.xpath("TEMPLATE/SCHED_ACTION/REPEAT").equals("3") );
        assertTrue( bj.xpath("TEMPLATE/SCHED_ACTION/DAYS").equals("5") );

        res = bj.scheddelete(sa_id);
        assertTrue( res.getErrorMessage(), !res.isError() );

        bj.info();
        assertTrue( bj.xpath("TEMPLATE/SCHED_ACTION").isEmpty() );
    }
}
