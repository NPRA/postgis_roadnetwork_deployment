
# Deplay a routable database of the Norwegian road network

This repository is meant as a starting point for developing routing services on the Norwegian road network. The road network is downloaded from the official site at Geo-Norge, which is updated at about a monthly basis.

To use this repository the following is needed:
* Postgres database with pgrouting and postgis
* ogr2ogr installed from the computer where the deployment is done from

# Usage

````
git clone git@github.com:NPRA/postgis_roadnetwork_deployment.gi`
````

cd into the folder of the scripts and run:

`````
sh ./deploy_roadnetwork.sh
`````

You're welcome
