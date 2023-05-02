# modified program 2 to do searches on PubMed to avoid API request errors

# create NCBI API key:
# 1. sign in (using Google Sign-in): https://www.ncbi.nlm.nih.gov/account/
# 2. click on login name (top right)
# 3. click on "Create an API key"
# 
# store this key into a separate file ("api_keys.jl") as a dictionary


# load HTTP package
using HTTP

# function to perform pubmed search
function ncbi_mesh_search(pubmed_query, ncbi_key, output_file)

    # define as the number of search results from manually searching in pubmed rounded up to the nearest 10,000
    retmax = 90000
    retstart = 0
    global_retstart = 0

    # define query dictionary to send to the URL
    query_dict = Dict()

    # instantiate mesh dictionary
    mesh_dict = Dict()

    while (global_retstart <= retmax)
        # define base URL
        base_search_query = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi"

        # tell user what search will be performed
        println("hello. I will search PubMed for $pubmed_query")
        println(retstart)

        # fill dictionary
        query_dict["api_key"] = ncbi_key
        query_dict["db"] = "pubmed"
        query_dict["term"] = pubmed_query    
        query_dict["retmax"] = retmax
        query_dict["retstart"] = retstart

        # send query to esearch
        search_result = String(HTTP.post(base_search_query, body=HTTP.escapeuri(query_dict)))

        #print(search_result)

        # instantiate pmid_set
        pmid_set = Set()

        # parse through each result line
        for result_line in split(search_result, "\n")
            # println("\$\$\$\$\$ $result_line")

            # use a regular expression to capture the PMIDs from 
            # lines that match the pattern
            pmid_capture = match(r"<Id>(\d+)<\/Id>", result_line)

            # only push pmids for lines that contain the pattern
            if pmid_capture != nothing
                push!(pmid_set, pmid_capture[1])
            end

            retmax = parse(Int64, match(r"<Count>(.+)</Count>", search_result)[1])

        end


        # for pmid in pmid_set
        #     println("captured pmid is: $pmid")
        # end

        # convert set to a comma list
        id_string = join(collect(pmid_set), ",")
        println(length(id_string))

        # update query dictionary for fetch query
        base_fetch_query = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi"
        query_dict["db"] = "pubmed"
        query_dict["api_key"] = ncbi_key
        query_dict["id"] = id_string
        query_dict["rettype"] = "medline"
        query_dict["retmode"] = "text"
        # reset retstart to 0
        query_dict["retstart"] = 0


        # initialize try/catch variables
        success = false
        fetch_result = ""
        # try/catch while loop to avoid API errors
        while(!success)
            try
                sleep(2)
                # send query dictionary to efetch
                fetch_result = String(HTTP.post(base_fetch_query, body=HTTP.escapeuri(query_dict)))
                success = true # exits the while loop
            catch e
                println("Encountered $e. Re-attempting E-Fetch query.") # success remains false as an error was caught
            end
        end

        # print(fetch_result)

        # pull out MeSH descriptors from efetch results
        for fetch_line in split(fetch_result, "\n")

            # println("\$\$\$\$\$ $fetch_line")
            
            # define the mesh capture RegEx
            mesh_capture = match(r"MH  - \*?([^/]+)", fetch_line)

            # if the line has the pattern, extract the MeSH descriptor
            # and store into MeSH dictionary & tracking frequency
            if mesh_capture != nothing

                # store MeSH descriptors, keeping track of occurence 
                if haskey(mesh_dict, mesh_capture[1])
                    mesh_dict[mesh_capture[1]] += 1
                else
                    mesh_dict[mesh_capture[1]] = 1
                end

            end


        end

        # increment retstart and global_retstart by 10,000
        global_retstart += 10000
        retstart += 10000
        sleep(2)
    end

    # print out counts of MeSH descriptors
    print(output_file, "mesh|count\n")
    for mesh_descriptor in keys(mesh_dict)
        if mesh_dict[mesh_descriptor] > 1
            # println("$mesh_descriptor occurs $(mesh_dict[mesh_descriptor]) times")

            # prints unique mesh terms and counts to output file
            print(output_file, "$mesh_descriptor|$(mesh_dict[mesh_descriptor])\n")
        end
    end

    close(output_file)

end


# load file that contains api keys
include("./api_keys.jl") 

function main()

    println("hello! I hope you are having a nice day!!")

    ncbi_key = api_key["ncbi"]

    # replace with whatever your pubmed query is
    pubmed_query = "melanoma[majr]"

    #println(ncbi_key)

    # output file that mesh terms and counts will print to
    output_file = open("methods2023_pubmed_help_mesh_counts.txt", "w")


    ncbi_mesh_search(pubmed_query, ncbi_key, output_file)


    println("... that was fun!")


end


main()