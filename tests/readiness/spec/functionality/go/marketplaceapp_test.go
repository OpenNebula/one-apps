package goca_test

import (
	"testing"
	"goca"
	"strconv"
)

var mkt_app_name string = "new_mkt_app"

var mkt_app *goca.MarketPlaceApp

var mkt_app_tmpl string

var mkt_img_id uint
var market_id  uint

func TestSetUp(t *testing.T){
	var err error
	mkt_app_tmpl = "NAME= \"" + mkt_app_name + "\"\n" +
					"TYPE=image\n"

	//Create an image
	img_tmpl := "NAME = \"test_img_go" + "\"\n" +
				"PATH = /etc/hosts\n"

	mkt_img_id, err = goca.CreateImage(img_tmpl, 1)

	if err != nil {
	    t.Errorf("Test failed:\n" + err.Error())
	}

	mkt_app_tmpl += "ORIGIN_ID=" + strconv.Itoa(int(mkt_img_id)) + "\n"

	//Create a marketplace
	mkt_tmpl := "NAME = \"mkt-app-test\"\n" +
	"MARKET_MAD = \"http\"\n" +
	"BASE_URL = \"http://url/\"\n" +
	"PUBLIC_DIR = \"/var/loca/market-http\"\n"

	market_id, err = goca.CreateMarketPlace(mkt_tmpl)

	if err != nil {
	    t.Errorf("Test failed:\n" + err.Error())
	}

	mkt_app_tmpl += "MARKETPLACE_ID=\"" + strconv.Itoa(int(market_id)) + "\"\n"
}

func TestMPAppAllocate(t *testing.T){
	app_id, err := goca.CreateMarketPlaceApp(mkt_app_tmpl, int(market_id))

	if err != nil {
	    t.Errorf("Test failed:\n" + err.Error())
	}

	mkt_app = goca.NewMarketPlaceApp(app_id)
	mkt_app.Info()

	actual, _:= mkt_app.XMLResource.XPath("/MARKETPLACEAPP/NAME")

	if actual != mkt_app_name {
		t.Errorf("Test failed, expected: '%s', got:  '%s'", mkt_app_name, actual)
	}
}

func TestMPADelete(t *testing.T){
	err := mkt_app.Delete()

	if err != nil {
		t.Errorf("Test failed:\n" + err.Error())
	}
}

func TestTearDown(t *testing.T){
	//delete image
	img := goca.NewImage(mkt_img_id)
	err := img.Delete()

	if err != nil {
		t.Errorf("Test failed:\n" + err.Error())
	}

	//delete marketplace
	market := goca.NewMarketPlace(market_id)
	err = market.Delete()

	if err != nil {
		t.Errorf("Test failed:\n" + err.Error())
	}
}
