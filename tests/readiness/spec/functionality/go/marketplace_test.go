package goca_test

import (
	"testing"
	"goca"
)

var mkt_name string = "marketplace_test_go"

var market *goca.MarketPlace

var mkt_template string =  "NAME = \"" + mkt_name + "\"\n" +
						   "MARKET_MAD = \"http\"\n" +
						   "BASE_URL = \"http://url/\"\n" +
						   "PUBLIC_DIR = \"/var/loca/market-http\""


func TestMarketAllocate(t *testing.T){
	market_id, err := goca.CreateMarketPlace(mkt_template)

	if err != nil {
		t.Errorf("Test failed:\n" + err.Error())
	}

	market = goca.NewMarketPlace(market_id)
	market.Info()

	actual, _:= market.XMLResource.XPath("/MARKETPLACE/NAME")

	if actual != mkt_name {
		t.Errorf("Test failed, expected: '%s', got:  '%s'", mkt_name, actual)
	}
}

func TestMarketUpdate(t *testing.T){
	tmpl := "ATT1 = \"VAL1\""

	err := market.Update(tmpl, 1)

	if err != nil {
		t.Errorf("Test failed:\n" + err.Error())
	}

	market.Info()

	actual_mm, _ := market.XMLResource.XPath("/MARKETPLACE/TEMPLATE/MARKET_MAD")
	actual_1,  _ := market.XMLResource.XPath("/MARKETPLACE/TEMPLATE/ATT1")

	if actual_mm != "http" {
		t.Errorf("Test failed, expected: '%s', got:  '%s'", "http", actual_mm)
	}

	if actual_1 != "VAL1" {
		t.Errorf("Test failed, expected: '%s', got:  '%s'", "VAL1", actual_1)
	}
}

func TestMarketChmod(t *testing.T){
	err := market.Chmod(1,1,1,1,1,1,1,1,1)

	if err != nil {
		t.Errorf("Test failed:\n" + err.Error())
	}

	market.Info()

	expected := "111111111"
	actual, _ := market.XMLResource.XPath("/MARKETPLACE/PERMISSIONS")

	if actual != expected {
		t.Errorf("Test failed, expected: '%s', got:  '%s'", expected, actual)
	}
}

func TestMarketChown(t *testing.T){
	err := market.Chown(1,1)

	if err != nil {
		t.Errorf("Test failed:\n" + err.Error())
	}

	market.Info()

	expected_usr := "1"
	expected_grp := "1"
	actual_usr, _ :=market.XMLResource.XPath("/MARKETPLACE/UID")
	actual_grp, _ :=market.XMLResource.XPath("/MARKETPLACE/GID")

	if actual_usr != expected_usr {
		t.Errorf("Test failed, expected: '%s', got:  '%s'", expected_usr, actual_usr)
	}

	if actual_grp != expected_grp {
		t.Errorf("Test failed, expected: '%s', got:  '%s'", expected_grp, actual_grp)
	}
}

func TestMarketRename(t *testing.T){
	rename := mkt_name + "-renamed"
	err := market.Rename(rename)

	if err != nil {
		t.Errorf("Test failed:\n" + err.Error())
	}

	market.Info()

	actual, _:= market.XMLResource.XPath("/MARKETPLACE/NAME")

	if actual != rename {
		t.Errorf("Test failed, expected: '%s', got:  '%s'", rename, actual)
	}
}

func TestMarketDelete(t *testing.T){
	err := market.Delete()

	if err != nil {
		t.Errorf("Test failed:\n" + err.Error())
	}
}