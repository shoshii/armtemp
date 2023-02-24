# how to output operations list by Azure CLI
# az provider operation list --query "[?contains(name, 'DocumentDB')]"

import json

with open('cosmos_operations.json') as f:
    json_dict = json.load(f)
    for key, value in json_dict[0].items():
        print(key)
        if (key != "resourceTypes"):
            continue
        for resourceType in value:
            #print(resourceType)
            #print(resourceType['operations'])
            for operation in resourceType['operations']:
                print(operation['name'])
    