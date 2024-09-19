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

import javax.xml.xpath.XPath;
import javax.xml.xpath.XPathExpressionException;
import javax.xml.xpath.XPathFactory;

import org.junit.After;
import org.junit.AfterClass;
import org.junit.Before;
import org.junit.BeforeClass;
import org.junit.Test;
import org.opennebula.client.Client;
import org.opennebula.client.OneResponse;
import org.opennebula.client.OneSystem;
import org.opennebula.client.zone.Zone;
import org.w3c.dom.Node;

public class ZoneTest
{

    private static Zone     zone;

    private static Client client;

    private static OneResponse  res;

    /**
     * @throws java.lang.Exception
     */
    @BeforeClass
    public static void setUpBeforeClass() throws Exception
    {
        client      = new Client();
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
        zone    = new Zone(0, client);
    }

    /**
     * @throws java.lang.Exception
     */
    @After
    public void tearDown() throws Exception
    {
    }

    @Test
    public void info()
    {
        res = zone.info();
        assertTrue( res.getErrorMessage(), !res.isError() );

        assertTrue( zone.id() >= 0 );
    }

    @Test
    public void rename()
    {
        String name = "JavaZoneTest";
        res = zone.rename(name);
        assertTrue( res.getErrorMessage(), !res.isError() );

        res = zone.info();
        assertTrue( res.getErrorMessage(), !res.isError() );
        assertTrue( zone.getName().equals(name) );
    }

    @Test
    public void disable()
    {
        res = zone.info();
        assertTrue( res.getErrorMessage(), !res.isError() );
        assertTrue( zone.xpath("STATE").equals("0") );

        res = zone.enable(false);
        assertTrue( res.getErrorMessage(), !res.isError() );

        res = zone.info();
        assertTrue( res.getErrorMessage(), !res.isError() );
        assertTrue( zone.xpath("STATE").equals("1") );

        res = zone.enable(true);
        assertTrue( res.getErrorMessage(), !res.isError() );

        res = zone.info();
        assertTrue( res.getErrorMessage(), !res.isError() );
        assertTrue( zone.xpath("STATE").equals("0") );
    }
}
