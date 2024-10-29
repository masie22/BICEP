targetScope='subscription'
param virtualNetworkName string 
param virtualNetworkNameRG string
param subnetName string
var agwConfigs = concat(loadJsonContent('./ABc/abc-agwconfigs.json','agwConfig'),
                        loadJsonContent('./XYZ/oxyz-agwconfigs.json','agwConfig'))
var agwuniqueConfigs = [ for certs in agwConfigs : certs.keyvault_gw_cert]
var new = union(agwuniqueConfigs,agwuniqueConfigs)
// var file1 = loadJsonContent('./ABc/abc-agwconfigs.json').agwConfig
// var file2 = loadJsonContent('./XYZ/xyz-agwconfigs.json').agwConfig
// var agwConfigs = array(union(file1,file2))

resource newRG 'Microsoft.Resources/resourceGroups@2021-01-01' existing = {
  name: 'agw-bicep-test-rg'
}

resource agwVnet 'Microsoft.Network/virtualNetworks@2022-11-01' existing = {
   name: virtualNetworkName
   scope: resourceGroup(virtualNetworkNameRG)

  resource agwsubnet 'subnets@2022-11-01' existing = {
    name: subnetName
  }
}



module appGw '../../modules/agw.bicep' = {
  scope: resourceGroup(newRG.name)
  name: 'appgatewaymodule'  params: {
    subnetid: agwVnet::agwsubnet.id
    location: newRG.location
    agwConfigs: agwConfigs
  }
}
output agwcertop array = new
output agwop array = agwConfigs
