# r-irodsclient
This is an iRODS client API for the R language.   The client uses the iRODS REST API.

## Prerequisites
The R iRODS client API uses the REST API for communications with iRODS.  See [iRODS REST Repository](https://github.com/DICE-UNC/irods-rest) and [iRODS REST Documentation](https://github.com/DICE-UNC/irods-rest/blob/master/docs/iRODSRESTAPIDocumentation.pdf) for setting up the REST web services.

## Including the API Code and Creating a Connection Context
The first steps to use the API is to import the iRODS_API.R file and create an connection context object.  This is done as follows:

    source("/path/to/source/file/iRODS_API.R")
    context <- IrodsContext("localhost", "8080", "rods", "rods")

The arguments to the IrodsContext constructor are:
* irods_server - the hostname or address of the iRODS server 
* irods_rest_api_port - the port to connect to the iRODS REST API
* username - the iRODS user that is used for the connection to iRODS
* password - the password for the iRODS user  

> Note that the REST API Port is the port to connect to the REST API web service.  This is NOT the port to connect to the iCAT server. 

## Operations and Code Samples

For the following operations, it is assumed that the context object has already been created.

### getDataObjectContents

This routine gets the contents of a data object.  

Arguments:

* path - the path of the data object.
* binary - boolean to indicate whether the return value is a vector of hex numbers (TRUE) or a character vector (FALSE).

Code Example:

    res <- context$getDataObjectContents("/tempZone/home/rods/a.txt, FALSE)
    print(res)

### putDataObject

This routine puts a file into iRODS.

Arguments:

* sourcePath - the path on the OS for the file to be placed into iRODS
* irodsPath: - the destination to place the data object into iRODS

Code Example:

    context$putDataObject("/home/jjames/tmp.txt", "/tempZone/home/rods/tmp.txt")

### listCollection

Lists the contents of an iRODS collection.  This routine returns a list containing a list of dataObjects and collections.  The list is in the format:
list(dataObjects=(do1, do2, do3), collections=(coll1, coll2, coll3)) 

Arguments:

* path - the path on the iRODS collection

Code Example:

    context$listCollection("/tempZone/home/rods")
    for (coll in res[["collections"]]) {
        print(coll)
    }
    for (dataObj in res[[dataObjects"]]) {
        print(dataObj)
    }

### putCollection

Creates an iRODS collection.

Arguments:

* path - the full path in iRODS where the collection is to be created

Code Example:

    context$putCollection("/tempZone/home/rods/temp")

### rmCollection

Removes an iRODS collection.

Arguments:

* path - the path in iRODS of the collection to be removed 
* force - boolean flag (defaulting to FALSE) indicating if the force flag is to be sent

Code Example:

    context$rmCollection("/tempZone/home/rods/temp")

### getCollectionMetadata

Gets the metadata for a collection.  The return value is a list of named lists representing the metadata
on the collection.  This list looks like the following:
((attr=attr1, val=val1, unit=unit1), (attr=attr2, val=val2, unit=unit2), ...)  

Arguments:

* path - the full path in iRODS for the collection

Code Example:

    meta <- context$getCollectionMetadata("/tempZone/home/rods")
    for (row in meta) {
        print (row$attr)
        print(row$val)
        print(row$unit)
    }


### getDataObjectMetadata

Gets the metadata for a data object. The return value is a list of named lists representing the metadata
on the collection.  This list looks like the following:
((attr=attr1, val=val1, unit=unit1), (attr=attr2, val=val2, unit=unit2), ...)

Arguments:

* path - the full path in iRODS for the data object

Code Example:

    meta <- context$getDataObjectMetadata("/tempZone/home/rods/myfile.txt")
    for (row in meta) {
        print(row$attr)
        print(row$val)
        print(row$unit)
    }

### addDataObjectMetadata

Add metadata to a data object.

Arguments:

* path - the full path in iRODS for the data object
* avu_list - A list of named lists representing the metadata to be written.  The keys of the named lists must be "attr", "val", and "unit". 

Code Example:

     avu_list <- list()
     avu_list <- append(avu_list, list(list(attr="myAttr", val="myVal", unit="myUnit")))
     avu_list <- append(avu_list, list(list(attr="myAttr2", val="myVal2", unit="myUnit2")))
     context$addDataObjectMetadata("/tempZone/home/rods/tmp.txt", avu_list)

### deleteDataObjectMetadata

Delete metadata from a data object.  

Arguments:

* path - the full path in iRODS for the data object
* avu_list - A list of named lists representing the metadata to be deleted.  The keys of the named lists must be "attr", "val", and "unit".  

Code Example:

    avu_list <- list()
    avu_list <- append(avu_list, list(list(attr="myAttr", val="myVal", unit="myUnit")))
    avu_list <- append(avu_list, list(list(attr="myAttr2", val="myVal2", unit="myUnit2")))
    context$deleteDataObjectMetadata("/tempZone/home/rods/tmp.txt", avu_list)

### addCollectionMetadata

Add metadata to a collection. 

Arguments:

* path - the full path in iRODS for the collection 
* avu_list - A list of named lists representing the metadata to be added.  The keys of the named lists must be "attr", "val", and "unit". 

Code Example:

    avu_list <- list()
    avu_list <- append(avu_list, list(list(attr="myAttr", val="myVal", unit="myUnit")))
    avu_list <- append(avu_list, list(list(attr="myAttr2", val="myVal2", unit="myUnit2")))
    context$addCollectionMetadata("/tempZone/home/rods", avu_list)

### deleteCollectionMetadata

Delete metadata on a collection.

Arguments:

* path - the full path in iRODS for the collection
* avu_list - A list of named lists representing the metadata to be deleted.  The keys of the named lists must be "attr", "val", and "unit".

Code Example:

    avu_list <- list()
    avu_list <- append(avu_list, list(list(attr="myAttr", val="myVal", unit="myUnit")))
    avu_list <- append(avu_list, list(list(attr="myAttr2", val="myVal2", unit="myUnit2")))
    context$deleteCollectionMetadata("/tempZone/home/rods", avu_list)
 
