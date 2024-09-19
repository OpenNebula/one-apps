package main

    import (
        "goca"
		"fmt"
    )

    func main() {
		vnt_name := "go-vnt"

		//fetch the pool
		vnt_pool, err := goca.NewVNTemplatePool()

		if err != nil {
			fmt.Println(err)
			return
		}

		fmt.Println("VNTEMPLATE POOL:")
		fmt.Println(vnt_pool.XMLResource)

		//create a new vntemplate
		template := `NAME=go-vnt
					VN_MAD=bridge`

		_, err = goca.CreateVNTemplate(template)

		if err != nil {
			fmt.Println(err)
			return
		}

		//get vntemplate info by name (it use get_by_id function)
		vnt, err := goca.NewVNTemplateFromName(vnt_name)

		if err != nil {
			fmt.Println(err)
			return
		}

		vnt.Info()

		fmt.Println("VNTEMPLATE BODY:")
		fmt.Println(vnt.XMLResource)

		//update vntemplate
		extra_tmpl := "ADDED=BY_GOCA"
		err = vnt.Update(extra_tmpl, 1)

		if err != nil {
			fmt.Println(err)
			return
		}

		vnt.Info()

		new_attr, _ := vnt.XMLResource.XPath("/VNTEMPLATE/TEMPLATE/ADDED")

		fmt.Println("NEW ATTRIBUTE AFTER UPDATE:")
		fmt.Println(new_attr)

		//change the owner of a vntemplate
		err = vnt.Chown(1, 1)
		if err != nil {
			fmt.Println(err)
			return
		}

		vnt.Info()
		user, _  := vnt.XMLResource.XPath("/VNTEMPLATE/UID")
		group, _ := vnt.XMLResource.XPath("/VNTEMPLATE/GID")
		fmt.Println("NEW OWNER:")

		fmt.Printf("%s:%s\n", user, group)

		//change the permissions of the vntemplate
		err = vnt.Chmod(1,1,1,1,1,1,1,1,1)
		if err != nil {
			fmt.Println(err)
			return
		}

		vnt.Info()
		perms, _  := vnt.XMLResource.XPath("/VNTEMPLATE/PERMISSIONS")

		fmt.Println("NEW PERMISSIONS:")

		fmt.Println(perms)

		//clone the vntemplate
		err = vnt.Clone(vnt_name + "-cloned")
		if err != nil {
			fmt.Println(err)
			return
		}

		vnt2, err := goca.NewVNTemplateFromName(vnt_name + "-cloned")
		vnt2.Info()

		cloned_name, _ := vnt2.XMLResource.XPath("/VNTEMPLATE/NAME")

		fmt.Println("CLONED VNTEMPLATE:")
		fmt.Println(cloned_name)

		//delete cloned vntemplate
		err = vnt2.Delete()
		if err != nil {
			fmt.Println(err)
			return
		}

		vnt2, err = goca.NewVNTemplateFromName(vnt_name + "-cloned")

		fmt.Println("DELETE VNTEMPLATE BODY:")
		fmt.Println(err)

		//lock all for a vntemplate
		err = vnt.LockAll()
		if err != nil {
			fmt.Println(err)
			return
		}

		vnt.Info()
		lock, _  := vnt.XMLResource.XPath("/VNTEMPLATE/LOCK/LOCKED")

		fmt.Println("LOCK:")

		fmt.Println(lock)

		//unlock all for a vntemplate
		err = vnt.Unlock()
		if err != nil {
			fmt.Println(err)
			return
		}

		vnt.Info()
		lock, locked := vnt.XMLResource.XPath("/VNTEMPLATE/LOCK")

		fmt.Println("LOCK:")

		fmt.Println(locked)

		//instantiate the vntemplate
		vnet_id, err := vnt.Instantiate("", "")
		if err != nil {
			fmt.Println(err)
			return
		}

		fmt.Println("NET ID:")

		fmt.Println(vnet_id)

		vnt.Delete()
	}
