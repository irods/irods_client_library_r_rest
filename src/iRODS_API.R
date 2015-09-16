library("httr")
library(XML)
library(bitops)

# Sets up a context for a connection to the iRODS REST service..
#
# Args:
#  irods_server:         The hostname or address of the iRODS server. 
#  irods_rest_api_port:  The port to connect to the iRODS REST API. 
#  username:             The iRODS user that is used for the connection to iRODS.
#  password:             (optional) The password for the iRODS user. If this is 
#                        ommitted the password is read and decrypted from ~/.irods/.irodsA
# 
# Returns: 
#    A context object that can be used to execute further interactions with iRODS.
#
# Example of creating and using a context.
#
#    context <- IrodsContext("localhost", "8080", "rods", "rods")
#    res <- context$putDataObject("/var/lib/irods/myfile.txt", "/tempZone/home/rods/myfile.txt")
#
IrodsContext <- function(irods_server, irods_rest_api_port, username, password = NULL) {

   thisEnv <- environment()

   .irods_server <- irods_server
   .irods_rest_api_port <- irods_rest_api_port
   .username <- username

   if (is.null(password)) {
       .password <- obfiDecode()
   } else {
       .password <- password
   }

   .rest_url_prefix <- paste("http://") #, get(".username"), ":", get(".password"), sep="")
   .rest_url_prefix <- paste(.rest_url_prefix, "@", .irods_server, ":", sep="")
   .rest_url_prefix <- paste(.rest_url_prefix, .irods_rest_api_port, "/irods-rest/rest", sep="")

    me <- list(
        thisEnv = thisEnv,

        # Gets the URL prefix for the REST calls.
        getRestUrlPrefix = function() {
            return(get(".rest_url_prefix"))
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

            res <- GET(URLencode(irods_rest_url), authObj)

            # check for error
            stop_for_status(res)

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

            res <- POST(URLencode(irods_rest_url), body=list(uploadFile=upload_file(sourcePath)), authObj)

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

            res <- GET(URLencode(irods_rest_url), authObj, accept_xml())


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
        createCollection = function(path) {

            irods_rest_url <- paste(get("this")$getRestUrlPrefix(), "/collection", path, sep="")
            authObj <- get("this")$getAuthenticationObj()

            res <- PUT(URLencode(irods_rest_url), authObj)

            # check for error
            stop_for_status(res)

        },

        # Removes an iRODS collection.
        #
        # Args:
        #  path:  The path in iRODS where the collection is to be removed.
        #  force: Indicates if the force flag is to be sent with the collection removal.
        #
        # Returns:
        #  None
        #
        # Exception Handling:
        #   An error is returned when the REST service returns an error code.
        #
        removeCollection = function(path, force = FALSE) {

           irods_rest_url <- paste(get("this")$getRestUrlPrefix(), "/collection", path, sep="")
           authObj <- get("this")$getAuthenticationObj()

           if (force) {
               res <- DELETE(URLencode(irods_rest_url), authObj, body=list(force = "true"))
           } else {
               res <- DELETE(URLencode(irods_rest_url), authObj, body=list(force = "false"))
           }

           # check for error
           stop_for_status(res)
       },

        # Deletes an iRODS data object. 
        #
        # Args:
        #  path:  The path in iRODS where the data object is to be removed.
        #  force: Indicates if the force flag is to be sent with the data object removal.
        #
        # Returns:
        #  None
        #
        # Exception Handling:
        #   An error is returned when the REST service returns an error code.
        #
        removeDataObject = function(path, force = FALSE) {

           irods_rest_url <- paste(get("this")$getRestUrlPrefix(), "/collection", path, sep="")
           authObj <- get("this")$getAuthenticationObj()

           if (force) {
               res <- DELETE(URLencode(irods_rest_url), authObj, body=list(force = "true"))
           } else {
               res <- DELETE(URLencode(irods_rest_url), authObj, body=list(force = "false"))
           }

           # check for error
           stop_for_status(res)
       },


       # Method to get metadata.  This is called by getCollectionMetadata()
       # and getDataObjectMetadata().  The type should be either "collection"
       # or "dataObject"
       getMetadata = function(path, type) {

           irods_rest_url <- paste(get("this")$getRestUrlPrefix(), "/", type, path, "/metadata", sep="")
           authObj <- get("this")$getAuthenticationObj()

           res <- GET(URLencode(irods_rest_url), authObj, accept_xml())

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
               res <- POST(URLencode(irods_rest_url), authObj, body = xmlStr, content_type_xml())
           } else {
               res <- PUT(URLencode(irods_rest_url), authObj, body = xmlStr, content_type_xml())
           }

           # check for error
           stop_for_status(res)
       },

       # Adds metadata to a data object.
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
       #     both an "attr" and a "val" named parameter.
       #
       # Example:
       #
       # The following shows an example of using this method to set AVU's on
       # a data object:
       #
       # avu_list <- list()
       # avu_list <- append(avu_list, list(list(attr="myAttr", val="myVal", unit="myUnit")))
       # avu_list <- append(avu_list, list(list(attr="myAttr2", val="myVal2", unit="myUnit2")))
       # context$addDataObjectMetadata("/tempZone/home/rods/tmp.txt", avu_list)
       #
       addDataObjectMetadata = function(path, avu_list) {
           get("this")$addOrDeleteMetadata(path, avu_list, "dataObject")
       },

       # Deletes metadata from a data object.
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
       #     both an "attr" and a "val" named parameter.
       #
       deleteDataObjectMetadata = function(path, avu_list) {
          get("this")$addOrDeleteMetadata(path, avu_list, "dataObject", TRUE)
       },

       # Adds metadata to a collection.
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
       #     both an "attr" and a "val" named parameter.
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

       # Deletes metadata from a collection.
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
       #     both an "attr" and a "val" named parameter.
       #
       deleteCollectionMetadata = function(path, avu_list) {
           get("this")$addOrDeleteMetadata(path, avu_list, "collection", TRUE)
       }

    )


    assign("this", me, envir=thisEnv)
    class(me) <- append(class(me), "IrodsContext")
    return(me)
}

# This method reproduces the obfiDecode() C++ routine used by the CLI clients.
# It decrypts the password from the .irodsA file.
obfiDecode = function() {

    # Read the password file contents
    .irodsAFile <- "~/.irods/.irodsA"
    .in <- readChar(.irodsAFile, file.info(.irodsAFile)$size)

    # Get the mtime of the password file & 0xFFFF
    timeVal <- bitAnd(as.integer(file.info(.irodsAFile)[,"mtime"]), 0xFFFF)

    # Get the user ID from password file & 0xF5F
    uid <- bitAnd(file.info(.irodsAFile)[,"uid"], 0xF5F)


    nout <- 0 
    out <- '' 
    wheel <- rep(0, times = 26 + 26 + 10 + 15)
    headstring <- '' 

    wheel_len <- 26 + 26 + 10 + 15
    j <- 1
    for (i in 0:9) {
        wheel[j] = 48 + i
        j <- j+1
    }
    for (i in 0:25) {
        wheel[j] = 65 + i
        j <- j+1
    }
    for (i in 0:25) {
        wheel[j] = 97 + i
        j <- j+1
    }
    for (i in 0:14) {
        wheel[j] = 33 + i
        j <- j+1
    }

    too_short <- 0
    if (nchar(.in) < 7) {
        too_short <- 1
    }

    kpos <- 6
    i <- 6

    rval <- char_n_ascii(.in, 7)
    rval <- rval - 101 

    if ( rval > 15 || rval < 0 || too_short == 1 ) { # invalid key to short 
        stop("PASSWORD_NOT_ENCRYPTED")
    }

    seq <- 0
    if ( rval == 0 ) {
        seq <- 0xd768b678
    }
    if ( rval == 1 ) {
        seq <- 0xedfdaf56
    }
    if ( rval == 2 ) {
        seq <- 0x2420231b
    }
    if ( rval == 3 ) {
        seq <- 0x987098d8
    }
    if ( rval == 4 ) {
        seq <- 0xc1bdfeee
    }
    if ( rval == 5 ) {
        seq <- 0xf572341f
    }
    if ( rval == 6 ) {
        seq <- 0x478def3a
    }
    if ( rval == 7 ) {
        seq <- 0xa830d343
    }
    if ( rval == 8 ) {
        seq <- 0x774dfa2a
    }
    if ( rval == 9 ) {
        seq <- 0x6720731e
    }
    if ( rval == 10 ) {
        seq <- 0x346fa320
    }
    if ( rval == 11 ) {
        seq <- 0x6ffdf43a
    }
    if ( rval == 12 ) {
        seq <- 0x7723a320
    }
    if ( rval == 13 ) {
        seq <- 0xdf67d02e
    }
    if ( rval == 14 ) {
        seq <- 0x86ad240a
    }
    if ( rval == 15 ) {
        seq <- 0xe76d342e
    }

    addin_i <- 0
    my_out <- headstring
    my_in <- substring(.in, 2)  # skip leading .

    ii <- 0
    while (1==1) { 
        ii <- ii + 1 
        if ( ii == 6 ) {
            not_en <- 0
            if ( substring(.in, 1, 1) != '.' ) {
                not_en <- 1  # is not 'encrypted' 
            }

            # at this point my_out and headstring point to same memory location (in C) so changed headstring to my_out 
            if ( char_n_ascii(my_out, 1) != char_to_ascii('S') - ( ( bitAnd(rval, 0x7) ) * 2 ) ) {
                not_en <- 1
            }

            #encodedTime = ( ( headstring[1] - 'a' ) << 4 ) + ( headstring[2] - 'a' ) +
            #       ( ( headstring[3] - 'a' ) << 12 ) + ( ( headstring[4] - 'a' ) << 8 );

            # changed this from headstring to my_out because c code has my_out = headstring
            # and these are character pointers
            encodedTime = bitShiftL( char_n_ascii(my_out,2) - char_to_ascii('a'),  4 ) + 
                   ( char_n_ascii(my_out,3) - char_to_ascii('a') ) +
                   bitShiftL( ( char_n_ascii(my_out, 4) - char_to_ascii('a') ), 12 ) + 
                   bitShiftL( ( char_n_ascii(my_out ,5) - char_to_ascii('a') ), 8  ) 

            if ( obfiTimeCheck( encodedTime, timeVal ) == 1) {
                not_en <- 1
            }
      
            my_out <- out   # start outputing for real 
            if ( not_en == 1 ) {
                #while ( ( *out++ = *.in++ ) != '\0' ) {
                #    ;    /* return input string */
                #}
                stop("PASSWORD_NOT_ENCRYPTED")
            }
            #my_in <- .in
            my_in <- substring(my_in, 2)
        } else {
            found <- 0

            addin <- bitAnd(bitShiftR(seq, addin_i), 0x1f)
            addin <- addin + uid
            addin_i <- addin_i + 3
            if ( addin_i > 28 ) {
                addin_i <- 0
            }
            for (i in 1:wheel_len) {
                if ( substring(my_in, 1, 1) == ascii_to_char(wheel[i]) ) {  
                    j <- i - addin
                    while ( j < 0 ) {
                        j <- j + wheel_len
                    }
                    my_out <- paste0(my_out, ascii_to_char(wheel[j]))
                    nout <- nout + 1
                    found = 1
                    break
                }
            }
            if ( found == 0 ) {
                if ( my_in == "") {  #char_to_ascii(substring(my_in, 1, 1)) == 0 ) {
                    return(my_out)
                }
                else {
                    #*my_out++ = *my_in;
                    my_out <- paste0(my_out, substring(my_in, 1, 1))
                    nout <- nout + 1
                }
            }
            my_in <- substring(my_in, 2)    #my_in++
        }
    }
}

# Returns the ASCII numeric value for the char.
char_to_ascii <- function(char) { 
    strtoi(charToRaw(char),16L) 
}

# Returns the ASCII numeric value for the nth character in the string, str.
char_n_ascii <- function(str, n) { 
    char_to_ascii(substring(str, n, n)) 
}

# Returns the character with the ascii value of n
ascii_to_char <- function(n) { 
    rawToChar(as.raw(n)) 
}

obfiTimeCheck <- function(time1, time2) {
    fudge <- 20
    delta <- time1 - time2
    if ( delta < 0 ) {
        delta <- 0 - delta
    }
    if ( delta < fudge ) {
        return(0)
    }

    if ( time1 < 65000 ) {
        time1 <- time1 + 65535
    }
    if ( time2 < 65000 ) {
        time2 <- time2 + 65535
    }

    delta = time1 - time2
    if ( delta < 0 ) {
        delta <- 0 - delta
    }
    if ( delta < fudge ) {
        return(0)
    }

    return(1)
}


