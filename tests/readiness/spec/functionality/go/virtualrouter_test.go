package goca_test

import (
	"testing"
	"goca"
)

var vr_name string = "new_vr"

var vr *goca.VirtualRouter

var vr_template string = "NAME = \"" + vr_name + "\"\n" +
						 "VROUTER = YES\n" +
						 "ATT1 = \"VAL1\"\n" +
						 "ATT2 = \"VAL2\""

func TestVirtualRouterAllocate(t *testing.T){
	vr_id, err := goca.CreateVirtualRouter(vr_template)

	if err != nil {
		t.Errorf("Test failed:\n" + err.Error())
	}

	vr = goca.NewVirtualRouter(vr_id)
	vr.Info()

	actual, _:= vr.XMLResource.XPath("/VROUTER/NAME")

	if actual != vr_name {
		t.Errorf("Test failed, expected: '%s', got:  '%s'", vr_name, actual)
	}
}

func TestVirtualRouterUpdate(t *testing.T){
	tmpl := "ATT3 = \"VAL3\""

	err := vr.Update(tmpl, 1)

	if err != nil {
	    t.Errorf("Test failed:\n" + err.Error())
	}

	vr.Info()

	actual_1, _ := vr.XMLResource.XPath("/VROUTER/TEMPLATE/ATT1")
	actual_3, _ := vr.XMLResource.XPath("/VROUTER/TEMPLATE/ATT3")

	if actual_1 != "VAL1" {
		t.Errorf("Test failed, expected: '%s', got:  '%s'", "VAL1", actual_1)
	}

	if actual_3 != "VAL3" {
		t.Errorf("Test failed, expected: '%s', got:  '%s'", "VAL3", actual_3)
	}
}

func TestVirtualRouterChmod(t *testing.T){
	err := vr.Chmod(1,1,1,1,1,1,1,1,1)

	if err != nil {
	    t.Errorf("Test failed:\n" + err.Error())
	}

	vr.Info()

	expected := "111111111"
	actual, _ := vr.XMLResource.XPath("/VROUTER/PERMISSIONS")

	if actual != expected {
		t.Errorf("Test failed, expected: '%s', got:  '%s'", expected, actual)
	}
}

func TestVirtualRouterChown(t *testing.T){
	err := vr.Chown(1,1)

	if err != nil {
	    t.Errorf("Test failed:\n" + err.Error())
	}

	vr.Info()

	expected_usr := "1"
	expected_grp := "1"
	actual_usr, _ := vr.XMLResource.XPath("/VROUTER/UID")
	actual_grp, _ := vr.XMLResource.XPath("/VROUTER/GID")

	if actual_usr != expected_usr {
		t.Errorf("Test failed, expected: '%s', got:  '%s'", expected_usr, actual_usr)
	}

	if actual_grp != expected_grp {
		t.Errorf("Test failed, expected: '%s', got:  '%s'", expected_grp, actual_grp)
	}
}

func TestVirtualRouterRename(t *testing.T){
	rename := vr_name + "-renamed"
	err := vr.Rename(rename)

	if err != nil {
	    t.Errorf("Test failed:\n" + err.Error())
	}

	vr.Info()

	actual, _:= vr.XMLResource.XPath("/VROUTER/NAME")

	if actual != rename {
		t.Errorf("Test failed, expected: '%s', got:  '%s'", rename, actual)
	}
}

func TestVirtualRouterInstantiate(t *testing.T){
	tmpl := "NAME = vrtemplate\n"+
			"CPU = 0.1\n"+
			"VROUTER = YES\n"+
			"MEMORY = 64\n"

	tmpl_id, err := goca.CreateTemplate(tmpl)

	if err != nil {
	    t.Errorf("Test failed:\n" + err.Error())
	}

	vr.Instantiate(1, int(tmpl_id), "vr_test_go", false, "")

	vm, err := goca.NewVMFromName("vr_test_go")

	if err != nil {
	    t.Errorf("Test failed:\n" + err.Error())
	}

	vm.TerminateHard()
	template := goca.NewTemplate(tmpl_id)

	template.Delete()
}

func TestVirtualRouterAttachNic(t *testing.T){
	vn_tmpl := "NAME = \"go-net\"\n"+
			   "BRIDGE = vbr0\n" +
			   "VN_MAD = dummy\n"

	vnet_id, _ := goca.CreateVirtualnetwork(vn_tmpl, 0)

	nic_tmpl := "NIC = [ NETWORK=\"go-net\" ]"

	err := vr.AttachNic(nic_tmpl)

	if err != nil {
	    t.Errorf("Test failed:\n" + err.Error())
	}

	vr.Info()

	actual, _:= vr.XMLResource.XPath("/VROUTER/TEMPLATE/NIC/NETWORK")

	if actual != "go-net" {
		t.Errorf("Test failed, expected: '%s', got:  '%s'", "go-net", actual)
	}

	vnet := goca.NewVirtualNetwork(vnet_id)
	vnet.Delete()
}

func TestVirtualRouterDetachNic(t *testing.T){
	err := vr.DetachNic(0)

	if err != nil {
	    t.Errorf("Test failed:\n" + err.Error())
	}
}

func TestVirtualRouterLock(t *testing.T){
	err := vr.LockAll()

	if err != nil {
	    t.Errorf("Test failed:\n" + err.Error())
	}

	vr.Info()

	actual, _:= vr.XMLResource.XPath("/VROUTER/LOCK/LOCKED")
	if actual != "4" {
		t.Errorf("Test failed, expected: '%s', got:  '%s'", "4", actual)
	}
}

func TestVirtualRouterUnlock(t *testing.T){
	err := vr.Unlock()

	if err != nil {
	    t.Errorf("Test failed:\n" + err.Error())
	}

	vr.Info()

	actual, _:= vr.XMLResource.XPath("/VROUTER/LOCK/LOCKED")
	if actual != "" {
		t.Errorf("Test failed, expected: '%s', got:  '%s'", "", actual)
	}
}

func TestVirtualRouterDelete(t *testing.T){
	err := vr.Delete()

	if err != nil {
		t.Errorf("Test failed:\n" + err.Error())
	}
}