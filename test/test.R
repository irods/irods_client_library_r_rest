source("../src/iRODS_API.R")
source("config.R")

context <- IrodsContext(REST_SERVER_HOST, REST_SERVER_PORT, IRODS_USER_USERNAME, IRODS_USER_PASSWORD)
path <- paste("/", IRODS_SERVER_ZONE, "/home/", IRODS_USER_USERNAME, sep="")
test_filename_only <- "test_file_in_irods.txt"
test_file_path <- paste(path, "/", test_filename_only, sep="")
test_collection_path <- paste(path, "/coll1", sep="")


hasMetadata <- function(meta_data_list, attr, val, unit) {
    for (row in res) {
        if (row$attr == attr && row$val == val && row$unit == unit) {
            return(TRUE) 
         }
    }
    return(FALSE)
}

cleanup <- function() {
    res <- context$listCollection(path)
    if (test_collection_path %in% res$collections) {
        context$removeCollection(test_collection_path)
    }
    if (test_filename_only %in% res$dataObjects) {
        context$removeDataObject(test_file_path)
    }        
}


cleanup()

print("Test putDataObject")
context$putDataObject("testfile.txt", test_file_path)

print("Test getDataObjectContents")
res <- context$getDataObjectContents(test_file_path)
stopifnot(res == "This is a test file.\n")

print("Test createCollection")
context$createCollection(test_collection_path)

print("Test listCollection")
res <- context$listCollection(path)
stopifnot(test_collection_path %in% res$collections)
stopifnot(test_filename_only %in% res$dataObjects)


avu_list <- list()
avu_list <- append(avu_list, list(list(attr="myAttr", val="myVal", unit="myUnit")))
avu_list <- append(avu_list, list(list(attr="myAttr2", val="myVal2", unit="myUnit2")))

print("Test addDataObjectMetadata")
context$addDataObjectMetadata(test_file_path, avu_list)

print("Test getDataObjectMetadata")
res <- context$getDataObjectMetadata(test_file_path)
stopifnot(hasMetadata(res, "myAttr", "myVal", "myUnit") && hasMetadata(res, "myAttr2", "myVal2", "myUnit2"))

print("Test addCollectionMetadata")
context$addCollectionMetadata(test_collection_path, avu_list)

print("Test getCollectionMetadata")
res <- context$getCollectionMetadata(test_collection_path)
stopifnot(hasMetadata(res, "myAttr", "myVal", "myUnit") && hasMetadata(res, "myAttr2", "myVal2", "myUnit2"))

print("Test deleteDataObjectMetadata")
context$deleteDataObjectMetadata(test_file_path, avu_list)
res <- context$getDataObjectMetadata(test_file_path)
stopifnot(!(hasMetadata(res, "myAttr", "myVal", "myUnit") && hasMetadata(res, "myAttr2", "myVal2", "myUnit2")))

print("Test deleteCollectionMetadata")
context$deleteCollectionMetadata(test_collection_path, avu_list)
res <- context$getCollectionMetadata(test_collection_path)
stopifnot(!(hasMetadata(res, "myAttr", "myVal", "myUnit") && hasMetadata(res, "myAttr2", "myVal2", "myUnit2")))

print("Test removeCollection")
context$removeCollection(test_collection_path)
res <- context$listCollection(path)
stopifnot(!(test_collection_path %in% res$collections))

cleanup()
