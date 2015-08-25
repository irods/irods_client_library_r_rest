library("httr")
library(XML)

# Sets up a context for a connection to the iRODS REST service..
#
# Args:
#  irods_server:         The hostname or address of the iRODS server. 
#  irods_rest_api_port:  The port to connect to the iRODS REST API. 
#  username:             The iRODS user that is used for the connection to iRODS.
#  password:             The password for the iRODS user.
# 
# Returns: 
#    A context object that can be used to execute further interactions with iRODS.
#
# Example of creating and using a context.
#
#    context <- IrodsContext("localhost", "8080", "rods", "rods")
#    res <- context$putDataObject("/var/lib/irods/myfile.txt", "/tempZone/home/rods/myfile.txt")
#
IrodsContext <- function(irods_server, irods_rest_api_port, username, password) {

   thisEnv <- environment()
   
   .irods_server <- irods_server
   .irods_rest_api_port <- irods_rest_api_port
   .username <- username
   .password <- password

    me <- list(
        thisEnv = thisEnv,
        
        # Gets the URL prefix for the REST calls. 
        getRestUrlPrefix = function() {
            rest_url_prefix <- paste("http://") #, get(".username"), ":", get(".password"), sep="")
            rest_url_prefix <- paste(rest_url_prefix, "@", get(".irods_server"), ":", sep="")
            rest_url_prefix <- paste(rest_url_prefix, get(".irods_rest_api_port"), "/irods-rest/rest", sep="") 
            return(rest_url_prefix)
        },

        # Gets and authentication object with the supplied username and password.
        getAuthenticationObj = function() {
            authenticate(get(".username"), get(".password"))    
        },


        # Returns the contents of a data object.
        #
        # Args:
        #  path:    The path of the data object.
        #  binary:  Boolean to indicate whether the return value is a vector
        #           of hex numbers (TRUE) or a character vector (FALSE). 
        # 
        # Returns: 
        #   The contents of the data object as either a vector of hex numbers
        #   or a character vector.
        #
        # Exception Handling:
        #   An error is returned when the REST service returns an error code.
        #
        getDataObjectContents = function(path, binary = FALSE) {

            irods_rest_url <- paste(get("this")$getRestUrlPrefix(), "/fileContents", path, sep="")
            authObj <- get("this")$getAuthenticationObj()

            res <- GET(irods_rest_url, authObj)
            
            # check for error 
            stop_for_status(res)
 
            # return content
           
            if (binary == TRUE) {
                content(res, "raw")
            } else { 
                content(res, "text")
            }

        },

        # Puts a file into iRODS.
        #
        # Args:
        #  sourcePath:  The path on the OS for the file to be placed into iRODS. 
        #  irodsPath:   The destination to place the data object into iRODS. 
        # 
        # Returns: 
        #  None
        #
        # Exception Handling:
        #   An error is returned when the REST service returns an error code.
        #
        putDataObject = function(sourcePath, irodsPath) {
      
            irods_rest_url <- paste(get("this")$getRestUrlPrefix(), "/fileContents", irodsPath, sep="")
            authObj <- get("this")$getAuthenticationObj()

            res <- POST(irods_rest_url, body=list(uploadFile=upload_file(sourcePath)), authObj)

            # check for error 
            stop_for_status(res)
        },

        # Lists the contents of an iRODS collection..
        #
        # Args:
        #  path:  The path on the iRODS collection. 
        # 
        # Returns: 
        #   An list containing a list of dataObjects and collections.  The list is in the format:
        #   list(dataObjects=(do1, do2, do3), collections=(coll1, coll2, coll3)) 
        #
        # Exception Handling:
        #   An error is returned when the REST service returns an error code.
        #
        # Example:
        #
        #   The following is an example of getting the lists of a collections and data objects, iterating
        #   over these lists, and printing the results. 
        #     
        #   res <- context$listCollection("/tempZone/home/rods")
        #   for (coll in res[["collections"]]) {
        #       print(coll)
        #   }
        #   for (dataObj in res[[dataObjects"]]) {
        #       print(dataObj)
        #   }
        #   
        listCollection = function(path) {

            irods_rest_url <- paste(get("this")$getRestUrlPrefix(), "/collection", path, "?listing=true&listType=both", sep="")
            authObj <- get("this")$getAuthenticationObj()

            res <- GET(irods_rest_url, authObj, accept_xml())

            #avu_list <- append(avu_list, list(list(attr=attr, val=val, unit=unit))) 
          

            # check for error 
            stop_for_status(res)

            # Parse the xml response and build a list of collections and a list of data objects.
            # Collections must be in a node that looks like the following:
            # <children>
            #   <objectType>COLLECTION</objectType>
            #   <pathOrName>xxx<pathOrName>
            # <children>
            # Data objects must be in a node that looks like the following:
            # <children>
            #   <objectType>DATA_OBJECT</objectType>
            #   <pathOrName>xxx<pathOrName>
            # <children>

            # First create empty lists for collections and dataObjects
            collections <- list()
            dataObjects <- list()

            # Now do parsing.
            xml_data <- xmlInternalTreeParse(res) 
            rootNode <- xmlChildren(xml_data)[[1]]
            children <- xmlChildren(rootNode)
            for (node in children) {
                if (xmlName(node) == "children") {
                    children2 <- xmlChildren(node)
                    pathOrName <- ""
                    objectType <- ""
                    for (node2 in children2) {
                        if (xmlName(node2) == "pathOrName") {
                            pathOrName <- xmlValue(node2)
                        } else if (xmlName(node2) == "objectType") {
                            objectType <- xmlValue(node2)
                        }
                    }
                    if (pathOrName != "") {
                        if (objectType == "COLLECTION") {
                            collections <- append(collections, pathOrName)
                        } else if (objectType == "DATA_OBJECT") {
                            dataObjects <- append(dataObjects, pathOrName) 
                        }
                    }
                }
            }

            returnVal = list()
            returnVal <- append(returnVal, list(collections=collections))
            returnVal <- append(returnVal, list(dataObjects=dataObjects))
            returnVal

        },

        # Creates an iRODS collection.
        #
        # Args:
        #  path:  The path in iRODS where the collection is to be created. 
        # 
        # Returns: 
        #  None
        #
        # Exception Handling:
        #   An error is returned when the REST service returns an error code.
        #
        putCollection = function(path) {

            irods_rest_url <- paste(get("this")$getRestUrlPrefix(), "/collection", path, sep="")
            authObj <- get("this")$getAuthenticationObj()

            res <- PUT(irods_rest_url, authObj)

            # check for error 
            stop_for_status(res)

        },

        # Remove an iRODS collection.  
        #
        # Args:
        #  path:  The path in iRODS where the collection is to be removed. 
        #  force: Indicates if if the force flag is to be sent with the collection removal.
        # 
        # Returns: 
        #  None
        #
        # Exception Handling:
        #   An error is returned when the REST service returns an error code.
        #
        rmCollection = function(path, force = FALSE) {

           irods_rest_url <- paste(get("this")$getRestUrlPrefix(), "/collection", path, sep="")
           authObj <- get("this")$getAuthenticationObj()

           if (force) {
               res <- DELETE(irods_rest_url, authObj, body=list(force = "true"))
           } else {
               res <- DELETE(irods_rest_url, authObj, body=list(force = "false"))
           }

           # check for error 
           stop_for_status(res)

           #res$status_code

       },

       # Method to get metadata.  This is called by getCollectionMetadata()
       # and getDataObjectMetadata().  The type should be either "collection"
       # or "dataObject"
       getMetadata = function(path, type) {

           irods_rest_url <- paste(get("this")$getRestUrlPrefix(), "/", type, path, "/metadata", sep="")
           authObj <- get("this")$getAuthenticationObj()

           res <- GET(irods_rest_url, authObj, accept_xml())

           # check for error 
           stop_for_status(res)

           avu_list <- list()

           xml_data <- xmlToList(xmlParse(content(res, "text")))

           for (row in xml_data) {
               attr <- ""
               val <- ""
               unit <- ""
               if ("attribute" %in% attributes(row)$names) {
                   attr <- row$attribute
               }
               if ("value" %in% attributes(row)$names) {
                   val <- row$value
               }
               if ("unit" %in% attributes(row)$names) {
                   unit <- row$unit
               }

               if (attr != "" || val != "" || unit != "") {
                   avu_list <- append(avu_list, list(list(attr=attr, val=val, unit=unit)))
               }
           }

           avu_list
       },

       # Gets the metadata for a collection.  
       #
       # Args:
       #  path:  The path in iRODS for the collection. 
       # 
       # Returns: 
       #   A list of named lists representing the metadata on the collection.  The
       #   keys of the named lists are "attr", "val", and "unit". 
       #
       # Exception Handling:
       #   An error is returned when the REST service returns an error code.
       #
       # Example:
       #
       # The following is an example of a call to this method and the extraction of metadata 
       # from the return value.
       #
       # meta <- context$getCollectionMetadata("/tempZone/home/rods")
       # for (row in meta) {
       #     print(row$attr)
       #     print(row$val)
       #     print(row$unit)
       # }
       #
       getCollectionMetadata = function(path) {
           get("this")$getMetadata(path, "collection")
       },

       # Gets the metadata for a data object. 
       #
       # Args:
       #  path:  The path in iRODS for the data object. 
       # 
       # Returns: 
       #   A list of named lists representing the metadata on the data object.  The
       #   keys of the named lists are "attr", "val", and "unit". 
       #
       # Exception Handling:
       #   An error is returned when the REST service returns an error code.
       #
       # Example:
       #
       # The following is an example of a call to this method and the extraction of metadata 
       # from the return value.
       #
       # meta <- context$getDataObjectMetadata("/tempZone/home/rods/myfile.txt")
       # for (row in meta) {
       #     print(row$attr)
       #     print(row$val)
       #     print(row$unit)
       # }
       #
       getDataObjectMetadata = function(path) {
           get("this")$getMetadata(path, "dataObject") 
       },

       # Method to add or delete metadata.  This is called by addCollectionMetadata(),
       # deleteCollectionMetadata(), addDataObjectMetadata(), and removeDataObjectMetadata().
       # The type should be either "collection" or "dataObject" and the deleteFlag is FALSE
       # for adds and TRUE for deletes.
       addOrDeleteMetadata = function(path, avu_list, type, deleteFlag = FALSE) {

           for (row in avu_list) {
               if (is.null(row[["attr"]])) {
                   stop("named value 'attr' is not in one of the avu's provided")
               }
               if (is.null(row[["val"]])) {
                   stop("named value 'val' is not in one of the avu's provided")
               }
           }

           xml_output <- xmlNode("ns2:metadataOperation", attrs = c("xmlns:ns2"="http://irods.org/irods-rest"))

           i <- 1
           for (row in avu_list) {
               if (!is.null(row[["unit"]])) {
                   xml_output$children[[i]] <- xmlNode("metadataEntries", xmlNode("attribute", row[["attr"]]), xmlNode("value", row[["val"]]),  xmlNode("unit", row[["unit"]]))
               } else {
                   xml_output$children[[i]] <- xmlNode("metadataEntries", xmlNode("attribute", row[["attr"]]), xmlNode("value", row[["val"]]))
               }

               i <- i + 1
           }


           irods_rest_url <- paste(get("this")$getRestUrlPrefix(), "/", type, path, "/metadata", sep="")
           authObj <- get("this")$getAuthenticationObj()

           xmlStr <- saveXML(xml_output, prefix='<?xml version="1.0"?>\n')

           if (deleteFlag) {
               res <- POST(irods_rest_url, authObj, body = xmlStr, content_type_xml())
           } else {
               res <- PUT(irods_rest_url, authObj, body = xmlStr, content_type_xml())
           }

           # check for error 
           stop_for_status(res)
       },

       # Add metadata to a data object. 
       #
       # Args:
       #  path:      The path in iRODS for the data object. 
       #  avu_list:  A list of named lists representing the metadata to be written.  The
       #             keys of the named lists must be "attr", "val", and "unit". 
       # 
       # Returns: 
       #   None:
       #
       # Exception Handling:
       #   An error is returned when the REST service returns an error code.
       #   An error is returned if any of the named lists in avu_list do not have
       #     both an "attr" and a "value" named parameter.
       #
       # Example:
       #
       # The following shows an example of using this method to set AVU's on
       # a data object:
       #
       # avu_list <- list()
       # avu_list <- append(avu_list, list(list(attr="myAttr", val="myVal", unit="myUnit"))
       # avu_list <- append(avu_list, list(list(attr="myAttr2', val="myVal2", unit="myUnit2"))
       # context$addDataObjectMetadata("/tempZone/home/rods/ab.txt", avu_list)
       #
       addDataObjectMetadata = function(path, avu_list) {
           get("this")$addOrDeleteMetadata(path, avu_list, "dataObject")
       },

       # Delete metadata from a data object. 
       #
       # Args:
       #  path:      The path in iRODS for the data object. 
       #  avu_list:  A list of named lists representing the metadata to be deleted.  The
       #             keys of the named lists must be "attr", "val", and "unit". 
       # 
       # Returns: 
       #   None:
       #
       # Exception Handling:
       #   An error is returned when the REST service returns an error code.
       #   An error is returned if any of the named lists in avu_list do not have
       #     both an "attr" and a "value" named parameter.
       #
       deleteDataObjectMetadata = function(path, avu_list) {
          get("this")$addOrDeleteMetadata(path, avu_list, "dataObject", TRUE)
       },

       # Add metadata to a collection. 
       #
       # Args:
       #  path:      The path in iRODS for the collection. 
       #  avu_list:  A list of named lists representing the metadata to be added.  The
       #             keys of the named lists must be "attr", "val", and "unit". 
       # 
       # Returns: 
       #   None:
       #
       # Exception Handling:
       #   An error is returned when the REST service returns an error code.
       #   An error is returned if any of the named lists in avu_list do not have
       #     both an "attr" and a "value" named parameter.
       #
       # The following shows an example of using this method to set AVU's on
       # a data object:
       #
       # avu_list <- list()
       # avu_list <- append(avu_list, list(list(attr="myAttr", val="myVal", unit="myUnit"))
       # avu_list <- append(avu_list, list(list(attr="myAttr2', val="myVal2", unit="myUnit2"))
       # context$addDataObjectMetadata("/tempZone/home/rods", avu_list)
       #
       addCollectionMetadata = function(path, avu_list) {
           get("this")$addOrDeleteMetadata(path, avu_list, "collection")
       },

       # Delete metadata from a collection. 
       #
       # Args:
       #  path:      The path in iRODS for the collection. 
       #  avu_list:  A list of named lists representing the metadata to be deleted.  The
       #             keys of the named lists must be "attr", "val", and "unit". 
       # 
       # Returns: 
       #   None:
       #
       # Exception Handling:
       #   An error is returned when the REST service returns an error code.
       #   An error is returned if any of the named lists in avu_list do not have
       #     both an "attr" and a "value" named parameter.
       #
       deleteCollectionMetadata = function(path, avu_list) {
           get("this")$addOrDeleteMetadata(path, avu_list, "collection", TRUE)
       }

    )


    assign("this", me, envir=thisEnv)
    class(me) <- append(class(me), "IrodsContext")
    return(me)
}

