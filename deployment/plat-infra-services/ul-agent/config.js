/*
 * UL Agent JavaScript config file.
 * See:
 * - https://github.com/telefonicaid/iotagent-ul/blob/master/config.js
 */
let config = {};


/* Use our Mosquitto service to receive device data and send commands
 * to devices.
 *
 * Notice we tell the agent to never prefix topics with a leading '/'
 * since that's bad practice. See:
 * - https://github.com/telefonicaid/iotagent-node-lib/issues/866
 * - https://www.hivemq.com/blog/mqtt-essentials-part-5-mqtt-topics-best-practices/
 */
config.mqtt = {
    host: 'mosquitto',
    port: 1883,
    protocol: 'mqtt',
    qos: 0,
    retain: false,
    retries: 5,
    retryTime: 5,
    keepalive: 60,
    avoidLeadingSlash: true,
    disabled: false
};

/* Don't attempt to connect to AMQP.
 * Setting `config.amqp.disabled` to `false` has no effect. The agent
 * will try connecting to `127.0.0.1:5672` every 5 secs. Probably a
 * bug. As a workaround, setting the whole `amqp` object to `null`
 * stops the agent from connecting. Not documented anywhere, but it
 * works.
 */
config.amqp = null;

/* HTTP endpoint to receive device data.
 * Quite confusingly, you've got to specify the path in the `iota`
 * section---see `iota.defaultResource` below. Anyway, the endpoint
 * for us is `ulagent:7896/iot/d`.
 */
config.http = {
    port: 7896
};

config.iota = {
    /* Device provisioning and management endpoint.
     * Listen on port 4041 and default the FIWARE service on device
     * registration to "kitt4sme".
     */
    server: {
        port: 4041
    },
    logLevel: 'DEBUG',
    service: 'kitt4sme',
    subservice: '/',

    /* Context Broker interaction.
     * Forward device data, after UL-to-NGSI-v2 translation, to our
     * Context Broker service at `orion:1026`. Use `kitt4sme` as a
     * default FIWARE service if the device registry doesn't hold
     * one for the device at hand.
     * Use the UL Agent service name and port when registering as a
     * Context Provider with Context Broker.
     */
    contextBroker: {
        host: 'orion',
        port: '1026',
        ngsiVersion: 'v2',
        fallbackTenant: 'kitt4sme',
        fallbackPath: '/'
    },
    providerUrl: 'http://ulagent:4041',

    /* In-memory device registry.
     * Since we configure device data to NGSI translation here and
     * have any changes propagated through our GitOps pipeline, we
     * don't have to stash away device registration and mapping in
     * Mongo DB. Also make sure device registration never expires,
     * since it's all in this config file.
     */
    deviceRegistry: {
        type: 'memory'
    },
    mongodb: {},
    deviceRegistrationDuration: 'P100Y',

    /* Device data to NGSI translation.
     * Put your mapping in the `types` map, our GitOps pipeline will
     * take care of updating the agent service with the new mapping.
     * See:
     * - https://iotagent-node-lib.readthedocs.io/en/latest/api.html#service-group-api
     * - https://iotagent-node-lib.readthedocs.io/en/latest/api.html#type-configuration
     */
    defaultResource: '/iot/d',
    defaultType: 'Thing',
    timestamp: true,
    explicitAttrs: false,
    autocast: true,
    types: {}
};

module.exports = config;
