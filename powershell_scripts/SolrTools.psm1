
function Push-ZookeeperConfig {
<#
.SYNOPSIS
Uploads a configuration set to Zookeeper.


.DESCRIPTION
Uploads a configuration set to Zookeeper from the provided file path.

.PARAMETER configPath
The path to the configuration files to upload to Zookeeper. This should be the contents of a solr /conf folder.

.PARAMETER configName
The name of the configuration to create in Zookeeper. If this config already exists it will be overwritten.

.PARAMETER zkHost
The IP address or hostname of an instance of Zookeeer. You only need one running Zookeeper in the ensemble.

.PARAMETER zkPost
The port the instance of Zookeeper specified by $zkHost is running on. 

.PARAMETER zkCliPath 
The path to the zkCli tool. 

.EXAMPLE
Push the contents of D:\SolrConfig\SitecoreConf to the Zookeeper running at 172.20.10.218 under the configuration name "sampleConf".

Push-ZookeeperConfig -configPath "D:\SolrConfig\SitecoreConf" -confName "sampleConf" -zkHost "172.20.10.218"

#>
    [CmdletBinding()]
    param (

        [Parameter(Mandatory=$True)]
        [string]$configPath,

        [Parameter(Mandatory=$True)]
        [string]$confName,

        [Parameter(Mandatory=$True)]
        [string]$zkHost = "172.20.10.218",
        
        [int]$zkPort = 2181,

        [string]$zkCliPath = "D:\solr\solr-5.2.1\server\scripts\cloud-scripts"
    )
    $zkCli = "zkCli.bat"

    Write-Verbose "Uploading config at $configPath to Zookeeper at ${zkHost}:${zkPort} with name $confName" 

    Start-Process -FilePath ${zkCliPath}\${zkcli} -ArgumentList "-zkhost ${zkHost}:${zkPort} -cmd upconfig -confdir ${configPath} -confname $confName"
}

function Get-ZookeeperConfig {
<#
    .SYNOPSIS
    Downloads a configuration set from Zookeeper.


    .DESCRIPTION
    Downloads a configuration set from Zookeeper to the provided file path. If this path already exists it will be overwritten.

    .PARAMETER configPath
    The path to save the configuration files to downloaded from Zookeeper.

    .PARAMETER configName
    The name of the configuration to pull from Zookeeper.

    .PARAMETER zkHost
    The IP address or hostname of an instance of Zookeeer. You only need one running Zookeeper in the ensemble.

    .PARAMETER zkPost
    The port the instance of Zookeeper specified by $zkHost is running on. 

    .PARAMETER zkCliPath 
    The path to the zkCli tool. 

    .EXAMPLE
    Get the contents from the Zookeeper running at 172.20.10.218 under the configuration name "sampleConf" and save it to D:\SolrConfig\SitecoreConf.

    Get-ZookeeperConfig -configPath "D:\SolrConfig\SitecoreConf" -confName "sampleConf" -zkHost "172.20.10.218"

#>

    [CmdletBinding()]
    param (

        [Parameter(Mandatory=$True)]
        [string]$configPath,

        [Parameter(Mandatory=$True)]
        [string]$confName,

        [Parameter(Mandatory=$True)]
        [string]$zkHost = "172.20.10.218",
        
        [int]$zkPort = 2181,

        [string]$zkCliPath = "D:\solr\solr-5.2.1\server\scripts\cloud-scripts"
    )
    $zkCli = "zkCli.bat"

    Write-Verbose "Downloading $confName config to $configPath from Zookeeper at ${zkHost}:${zkPort}" 

    Start-Process -FilePath ${zkCliPath}\${zkcli} -ArgumentList "-zkhost ${zkHost}:${zkPort} -cmd downconfig -confdir ${configPath} -confname $confName"

}

function Invoke-SolrReloadAllCollections {
<#
    .SYNOPSIS
    Reloads all collections in a Solr cluster.

    .DESCRIPTION
    Fetches a list of the collections from a Solr node, then iterates over those collections calling Reload on each. All commands are executed 
    via the REST API.

    .PARAMETER solrHost
    The IP address or hostname of an instance of Solr. You only need one running Solr address in the cloud.

    .PARAMETER solrPort
    The port the instance of Solr specified by $solrHost is running on. 

    .EXAMPLE
    Reload all the collections on the Solr Cloud cluster containing a node running at 172.20.10.218 port 8983.

    Invoke-SolrReloadAllCollections -solrHost "172.20.10.218"

#>

    [CmdletBinding()]
    param (

        [Parameter(Mandatory=$True)]
        [string]$solrHost = "172.20.10.218",
        
        [int]$solrPort = 8983
    )
    

    $solrUrl = "http://${solrHost}:${solrPort}/solr/admin/collections?action=LIST&wt=json"
    Write-Output "Getting collections from $solrUrl" 

    $jsonResult

    Invoke-RestMethod -Method Post -Uri $solrUrl -OutVariable jsonResult

    #Write-Output "Result: {0}`n" -f $jsonResult 

    foreach ($collection in $jsonResult.Collections) {    
        $reloadResult
        $reloadUrl = "http://${solrHost}:${solrPort}/solr/admin/collections?action=RELOAD&name=${collection}&wt=json"
        Write-Output "Reloading Collection: $collection "
        Invoke-RestMethod -Method Post -Uri $reloadUrl -OutVariable reloadResult | ConvertTo-Json

        #Write-Output "Result: {0}`n" -f $reloadResult
    }

}

function New-SolrCollectionsSitecore81 {
<#
    .SYNOPSIS
    Creates index collections for a brand.

    .DESCRIPTION
    Creates the set of collections needed to support a fresh Sitecore 8.1 environment in Solr. 
    Uses the default index names from Sitecore.
    

    .PARAMETER solrHost
    The IP address or hostname of an instance of Solr. You only need one running Solr address in the cloud.

    .PARAMETER solrPort
    The port the instance of Solr specified by $solrHost is running on. 

        
    .PARAMETER createSwitchCollections
    TRUE to create additonal collections to use during SwitchOnRebuild strategy.

    
    .PARAMETER configName
    The name of configuration set in Zookeeper to use for this collection.

    
    .PARAMETER solrNodes
    Comma delimited list of Solr node IPs or hostnames. These must be the Solr nodes which will host the collection shards and replicas.

    
    .PARAMETER numShards
    The number of shards this collection should belong to. There should only be one shard.

    
    .PARAMETER replicas
    The number of replicas to create for this collection. There should be 1 replica per Solr node.


    .EXAMPLE
    Create collections for Sitecore 8.1 on the Solr Cloud cluster containing a node running at 172.20.10.218 port 8983. 

    New-SolrCollectionsForBrand -solrHost "172.20.10.218" -confName "sitecoreConf" -solrNodes @("172.20.10.218","172.20.10.219","172.20.10.220")

#>
    [CmdletBinding()]
    param (

        [Parameter(Mandatory=$True)]
        [string]$solrHost,
        
        [int]$solrPort = 8983,

        [bool]$createSwitchCollections = $FALSE,
        
        [Parameter(Mandatory=$True)]
        [string]$confName,
    
        [Parameter(Mandatory=$True)]
        [string[]]$solrNodes,

        [int] $numShards = 1,

        [int] $replicas = 3,
        
        [string[]] $collectionNames = 
            ("sitecore_testing_index", 
            "sitecore_suggested_test_index", 
            "sitecore_fxm_master_index", 
            "sitecore_fxm_web_index", 
            "sitecore_list_index", 
            "sitecore_analytics_index", 
            "sitecore_core_index", 
            "sitecore_master_index", 
            "sitecore_web_index")
    )

    #Build the solr url
    #example
    #http://localhost:8983/solr/admin/collections?action=CREATE&name=itembuckets&numShards=1&replicationFactor=3&createNodeSet=node1.hostname:8983_solr,node2.hostname:8983_solr,node3.hostname:8983_solr&collection.configName=sitecoreconf



    $nodes = @()
    foreach($zk in $solrNodes) { $nodes += "${zk}:${solrPort}_solr"}
    $joinedNodes = $nodes -join ","

    #URL Format: "http://${solrHost}:${solrPort}/solr/admin/collections?action=CREATE&name=$collectionName&numShards=$numShards&replicationFactor=$replicas&createNodeSet=$joinedNodes&collection.configName=$confName&wt=json"

    $solrUrls = @()
    foreach ($collectionName in $collectionNames) {
        $solrUrls += "http://${solrHost}:${solrPort}/solr/admin/collections?action=CREATE&name=$collectionName&numShards=$numShards&replicationFactor=$replicas&createNodeSet=$joinedNodes&collection.configName=$confName&wt=json"
        if ($createSwitchCollections)
        {
            $solrUrls += "http://${solrHost}:${solrPort}/solr/admin/collections?action=CREATE&name=${collectionName}_sec&numShards=$numShards&replicationFactor=$replicas&createNodeSet=$joinedNodes&collection.configName=$confName&wt=json"
        }
    }


    Write-Verbose "Creating collections from with the following commands`n" 
    $solrUrls | Write-Verbose     
    
    
    foreach ($url in $solrUrls) {    
        $createResult
        Write-Verbose "Creating collection with command: $url `n"
        Invoke-RestMethod -Method Post -Uri $url -OutVariable createResult | ConvertTo-Json   

        #Write-Output $createResult | fl

    }
}


function Remove-SolrCollectionsForSitecore81 {
<#
    .SYNOPSIS
    Removes index collections for Sitecore 8.1. Uses the standard index names by default.

    .DESCRIPTION
    Deletes the set of collections needed to support a brand in Solr. Uses the following format:
    Environment_InstanceBrand_Database(_sec)
    ex. Prod_OdysseyGillette_Master, BrandLoad_BrandcomDefault_Web, etc
    
    .PARAMETER solrHost
    The IP address or hostname of an instance of Solr. You only need one running Solr address in the cloud.

    .PARAMETER solrPort
    The port the instance of Solr specified by $solrHost is running on. 

    .PARAMETER deleteSwitchCollections
    TRUE to delete the additonal collections used during SwitchOnRebuild strategy.
    
    .EXAMPLE
    Delete the collections for Sitecore 8.1 on the Solr Cloud cluster containing a node running at 172.20.10.218 port 8983. 

    Remove-SolrCollectionsForSitecore81 -solrHost "172.20.10.218"

#>
    [CmdletBinding()]
    param (

        [Parameter(Mandatory=$True)]
        [string]$solrHost,
        
        [int]$solrPort = 8983,
        
        [bool]$deleteSwitchCollections = $FALSE,
        
        [string[]] $collectionNames = 
            ("sitecore_testing_index", 
            "sitecore_suggested_test_index", 
            "sitecore_fxm_master_index", 
            "sitecore_fxm_web_index", 
            "sitecore_list_index", 
            "sitecore_analytics_index", 
            "sitecore_core_index", 
            "sitecore_master_index", 
            "sitecore_web_index")
    )

    #Build the solr url
    #example
    #http://localhost:8983/solr/admin/collections?action=DELETE&name=itembuckets

    #URL Format: "http://${solrHost}:${solrPort}/solr/admin/collections?action=DELETE&name=$collectionName&wt=json"

    $solrUrls = @()
    foreach ($collectionName in $collectionNames) {
        $solrUrls += "http://${solrHost}:${solrPort}/solr/admin/collections?action=DELETE&name=$collectionName&wt=json"
        if ($deleteSwitchCollections)
        {
            $solrUrls += "http://${solrHost}:${solrPort}/solr/admin/collections?action=DELETE&name=${collectionName}_sec&wt=json"
        }
    }


    Write-Verbose "Removing collections from with the following commands`n" 
    $solrUrls | Write-Verbose     
    
    
    foreach ($url in $solrUrls) {    
        $deleteResult
        Write-Verbose "Deleting collection with command: $url `n"
        Invoke-RestMethod -Method Post -Uri $url -OutVariable deleteResult | ConvertTo-Json           
    }
}