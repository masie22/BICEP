param location string = resourceGroup().location
param subnetid string
var keyvault_name ='devtest-kv'
var agwname = 'centralus-devtest-agw'
param agwConfigs array
var agwuniqueConfigs = [ for certs in agwConfigs : certs.keyvault_gw_cert]
var sslcerts = union(agwuniqueConfigs,agwuniqueConfigs)

var vault_uri = environment().suffixes.keyvaultDns

resource existing_keyvault 'Microsoft.KeyVault/vaults@2020-04-01-preview' existing = {
  name : keyvault_name
}

resource mgmtIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${location}-devtest-agw-identity'
  location: location
}
resource appGwIP 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: '${location}-devtest-agw-pip'
  location: location
  sku: {
    name: 'Standard'
  }  properties: {
    publicIPAllocationMethod: 'Static'
  }
}
resource applicationGateway 'Microsoft.Network/applicationGateways@2022-11-01' = {
  name:agwname
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '/subscriptions/4b-69b38d64/resourceGroups/agw-bicep-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${mgmtIdentity.name}':{}    }  }  properties:{    sku:{      name:'Standard_v2'      tier: 'Standard_v2'    }    gatewayIPConfigurations: [      {        name: 'appGatewayIpConfig'        properties: {          subnet: {            id: subnetid          }        }      }    ]    sslCertificates: [for certs in sslcerts : (certs != null && certs != '""') ? {        name: '${certs}'        properties: {          keyVaultSecretId: 'https://${existing_keyvault.name}${vault_uri}/secrets/${certs}'        }      } : {}]    frontendIPConfigurations: [      {        name: 'agwPublicFrontendIp'        properties: {          privateIPAllocationMethod: 'Dynamic'          publicIPAddress: {            id: resourceId('Microsoft.Network/publicIPAddresses', appGwIP.name)          }        }      }    ]
      frontendPorts: [
        {
          name: '${location}-hubdev-feport-http'
          properties: {
            port: 80
          }
        }
        {
          name: '${location}-hubdev-feport-https'
          properties: {
            port: 8080
          }
        }
        ]
        backendAddressPools: [for config in agwConfigs: {
          name: '${config.appName}-backendpool'
          properties: {}
        }]
  backendHttpSettingsCollection: [for config in agwConfigs: {
    name: '${config.appName}-httpsettings'
    properties: {
      port: config.backendPort
      protocol: config.protocol
      cookieBasedAffinity: 'Disabled'
      pickHostNameFromBackendAddress: false
      requestTimeout: 20
    }
  }]
  httpListeners: [for config in agwConfigs: (config.protocol == 'https') ? {
    name: '${config.appName}-${config.protocol}-listener'
    properties: {
      protocol: config.protocol
       hostName: contains(config,'hostName') ? config.hostName : null
       requireServerNameIndication: true
       hostNames: contains(config,'hostNames') ? config.hostNames : []
       frontendIPConfiguration: {
        id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', agwname, 'agwPublicFrontendIp')
      }
      frontendPort: {
        id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', agwname, '${location}-hubdev-feport-${config.protocol}')
      }
      sslCertificate: {
        id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', agwname, '${config.keyvault_gw_cert}')
      }
    }
  } : {
    name: '${config.appName}-${config.protocol}-listener'
    properties: {
      protocol: config.protocol
      hostName: contains(config,'hostName') ? config.hostName : null
      requireServerNameIndication: false
      hostNames: contains(config,'hostNames') ? config.hostNames : []
      frontendIPConfiguration: {
        id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', agwname, 'agwPublicFrontendIp')
      }
      frontendPort: {
        id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', agwname, '${location}-hubdev-feport-${config.protocol}')
      }
    }
  }]
  requestRoutingRules: [for config in agwConfigs: {
    name: '${config.appName}-${config.protocol}-routingrule' 
    properties: {
      priority: config.priority
      ruleType: 'Basic'
      httpListener: {
        id: resourceId('Microsoft.Network/applicationGateways/httpListeners', agwname, '${config.appName}-${config.protocol}-listener')
      }
      backendAddressPool: {
        id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', agwname, '${config.appName}-backendpool')
      } 
      backendHttpSettings: {
        id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', agwname, '${config.appName}-httpSettings')
      }
    }
  }]
  autoscaleConfiguration: {
    minCapacity: 0
    maxCapacity: 10
  }
}
}
