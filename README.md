# mongodb test

This repository takes care of deploying a mongodb test instances. The environment is managed via the [AppFlow UI](https://control.vshn.net/appflow/apps/vshn/nunki-mongodb).

## Setup

The following pipeline variables are required for the AppFlow deployment:

- MONGODB_PVC_SIZE_GI
- OPENBAO_SVC_NAME
- OPENBAO_NAMESPACE

### Usage with ExternalSecrets and Vault/OpenBAO

You need to set the following .env keys:

- `OPENBAO_SECRETS_PATH_PREFIX`: To the path you will store your secrets. See [values.yaml](./values.yaml) for details.

And then set `secretManagement: "externalsecrets"`.

And then configure the following in Vault/OpenBAO:

- `backupEncryptionSecret`: `pwgen 32 1`
- `luksKey`: `pwgen -c -s 64 1`
- `replicaSetKey`: `openssl rand -base64 756`
- `rootPassword`: `pwgen 32 1`

(The password generation commands are just examples.)

## replication

Currently replication isn't configured automatically.
Once all replicas have successfully started we need to exec into one of the pods and run the following command via mongosh

```mongodb-json
rs.initiate({
   _id: "mongodb-nunki",
   version: 1,
   members: [
{ _id: 0, host: "mongodb-0.app-mongodb-dev.svc.cluster.local:27017" },
      { _id: 1, host: "mongodb-1.app-mongodb-dev.svc.cluster.local:27017" },
      { _id: 2, host: "mongodb-2.app-mongodb-dev.svc.cluster.local:27017" }
   ]
 })
```

If it is broken you can fix it with:

```shell
rs.reconfig({
    _id: "mongodb-nunki",
    version: 1,
    members: [
      { _id: 0, host: "mongodb-0.app-mongodb-dev.svc.cluster.local:27017" },
      { _id: 1, host: "mongodb-1.app-mongodb-dev.svc.cluster.local:27017" },
      { _id: 2, host: "mongodb-2.app-mongodb-dev.svc.cluster.local:27017" }
    ]
  }, {force: true})
```

## LUKS encryption:

See https://docs.appuio.cloud/user/how-to/encrypted-volumes.html

## testing

There is a job spec in ./test that runs a few queries on the imported [sample datasets](https://www.mongodb.com/docs/manual/sample-data/) in a loop.
