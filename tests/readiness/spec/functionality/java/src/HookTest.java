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
import org.opennebula.client.hook.Hook;
import org.opennebula.client.hook.HookPool;

public class HookTest
{
    private static Hook hook;
    private static HookPool hookPool;

    private static Client client;

    private static OneResponse res;

    private static String name = "new_test_hook";

    /**
     * @throws java.lang.Exception
     */
    @BeforeClass
    public static void setUpBeforeClass() throws Exception
    {
        client   = new Client();
        hookPool = new HookPool(client);
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
        String template = "NAME    = " + name + "\n" +
                          "TYPE    = api\n" +
                          "COMMAND = \"/usr/bin/ls -l\"\n" +
                          "CALL    = \"one.zone.raftstatus\"";

        res = Hook.allocate(client, template);
        int hookid = res.isError() ? -1 : Integer.parseInt(res.getMessage());

        hook = new Hook(hookid, client);

        try { Thread.sleep(5000); } catch (Exception e){}
    }

    /**
     * @throws java.lang.Exception
     */
    @After
    public void tearDown() throws Exception
    {
        hook.delete();
    }

    @Test
    public void allocate()
    {
        res = hookPool.info();
        assertTrue( res.getErrorMessage(), !res.isError() );

        boolean found = false;
        for(Hook hook : hookPool)
        {
            found = found || hook.getName().equals(name);
        }

        assertTrue( found );
    }

    @Test
    public void update()
    {
        res = hook.update("VAL1 = VALA", true);
        assertTrue( res.getErrorMessage(), !res.isError() );

        res = hook.info();
        assertTrue( res.getErrorMessage(), !res.isError() );
        assertTrue( hook.xpath("TEMPLATE/VAL1").equals("VALA") );
    }

    @Test
    public void retry()
    {
        client.call("zone.raftstatus");

        try { Thread.sleep(1000); } catch (Exception e){}

        res = hook.retry(0);
        assertTrue( res.getErrorMessage(), !res.isError() );
    }

    @Test
    public void delete()
    {
        res = hook.delete();
        assertTrue( res.getErrorMessage(), !res.isError() );

        res = hook.info();
        assertTrue( res.isError() );
    }
}
