'use strict';
var tape = require('../lib/thali-tape');
var express = require('express');
var crypto = require('crypto');
var Promise = require('lie');
var http = require('http');

var httpTester = require('../lib/httpTester.js');

var ThaliMobile =
  require('thali/NextGeneration/thaliMobile');
var NotificationAction =
  require('thali/NextGeneration/notification/thaliNotificationAction');
var PeerDictionary =
  require('thali/NextGeneration/notification/thaliPeerDictionary');
var NotificationBeacons =
  require('thali/NextGeneration/notification/thaliNotificationBeacons');
var MakeIntoCloseAllServer =
  require('thali/NextGeneration/makeIntoCloseAllServer');
var NotificationCommmon =
  require('thali/NextGeneration/notification/thaliNotificationCommon');
var ThaliPeerAction =
  require('thali/NextGeneration/thaliPeerPool/thaliPeerAction');

var SECP256K1 = 'secp256k1';

var globals = {};

/**
 * @classdesc This class is a container for all variables and
 * functionality that are common to most of the ThaliNoficationServer
 * tests.
 */
var GlobalVariables = function () {

  this.expressApp = express();
  this.expressRouter = express.Router();

  this.sourceKeyExchangeObject = crypto.createECDH(SECP256K1);
  this.sourcePublicKey = this.sourceKeyExchangeObject.generateKeys();
  this.sourcePublicKeyHash =
    NotificationBeacons.createPublicKeyHash(this.sourcePublicKey);

  this.createPublicKeysToNotifyAndPreamble();
};

GlobalVariables.prototype.init = function () {
  var self = this;
  return new Promise(function (resolve, reject) {
    // Initializes the server with the expressRouter
    self.expressApp.use('/', self.expressRouter);
    self.expressServer = self.expressApp.listen(0, function (err) {
      if (err) {
        reject(err);
      } else {
        MakeIntoCloseAllServer(self.expressServer);
        resolve();
      }
    });
  });
};

/**
 * Frees reserved resources from globals after the each test run.
 */
GlobalVariables.prototype.kill = function () {

  var self = this;
  return new Promise(function (resolve, reject) {
    if (self.expressServer) {

      self.expressServer.closeAll(function (error) {

        self.expressServer = null;
        if (error != null) {
          reject(error);
        } else {
          resolve();
        }
      });
    } else {
      resolve();
    }
  });
};

GlobalVariables.prototype.createPublicKeysToNotifyAndPreamble = function () {
  this.targetPublicKeysToNotify = [];
  this.targetPublicKeysToNotifyHashes = [];
  this.targetDeviceKeyExchangeObjects = [];
  this.preambleAndBeacons = {};

  var device1 = crypto.createECDH(SECP256K1);
  var device1Key = device1.generateKeys();
  var device1KeyHash = NotificationBeacons.createPublicKeyHash(device1Key);

  var device2 = crypto.createECDH(SECP256K1);
  var device2Key = device2.generateKeys();
  var device2KeyHash = NotificationBeacons.createPublicKeyHash(device2Key);

  this.targetPublicKeysToNotify.push(device1Key, device2Key);
  this.targetPublicKeysToNotifyHashes.push(device1KeyHash, device2KeyHash);
  this.targetDeviceKeyExchangeObjects.push(device2, device2);

  this.preambleAndBeacons =
    NotificationBeacons.generatePreambleAndBeacons(
      this.targetPublicKeysToNotify, this.sourceKeyExchangeObject,
      60 * 60 * 1000);
};

var addressBookCallback = function (unencryptedKeyId) {
  if (unencryptedKeyId.compare(globals.sourcePublicKeyHash) === 0) {
    return globals.sourcePublicKey;
  }
  return null;
};

var test = tape({
  setup: function (t) {
    globals = new GlobalVariables();
    globals.init().then(function () {
      t.end();
    }).catch(function (failure) {
      t.fail('Test setting up failed:' + failure);
      t.end();
    });
  },
  teardown: function (t) {
    globals.kill().then(function () {
      t.end();
    }).catch(function (failure) {
      t.fail('Server cleaning failed:' + failure);
      t.end();
    });
  }
});

test('Test BEACONS_RETRIEVED_AND_PARSED locally', function (t) {

  t.plan(2);

  httpTester.runServer(globals.expressRouter,
    NotificationCommmon.NOTIFICATION_BEACON_PATH,
    200, globals.preambleAndBeacons, 1);

  var connInfo = new PeerDictionary.PeerConnectionInformation('127.0.0.1',
    globals.expressServer.address().port, 2000);

  var act = new NotificationAction('hello',
    ThaliMobile.connectionTypes.TCP_NATIVE,
    globals.targetDeviceKeyExchangeObjects[0], addressBookCallback , connInfo);

  act.eventEmitter.on(NotificationAction.Events.Resolved, function (res) {
    t.equals(
        res,
        NotificationAction.ActionResolution.BEACONS_RETRIEVED_AND_PARSED,
        'Response should be BEACONS_RETRIEVED_AND_PARSED');
  });

  var keepAliveAgent = new http.Agent({ keepAlive: true });
  act.start(keepAliveAgent).then( function (res) {
    t.equals(res, null, 'must return null after successful call');
  })
  .catch(function (failure) {
    t.fail('Test failed:' + failure);
  });
});

test('Test HTTP_BAD_RESPONSE locally', function (t) {

  t.plan(2);

  httpTester.runServer(globals.expressRouter,
    NotificationCommmon.NOTIFICATION_BEACON_PATH, 503, 'hello', 1);

  var connInfo = new PeerDictionary.PeerConnectionInformation('127.0.0.1',
    globals.expressServer.address().port, 2000);

  var act = new NotificationAction('hello',
    ThaliMobile.connectionTypes.TCP_NATIVE,
    globals.targetDeviceKeyExchangeObjects[0], addressBookCallback , connInfo);

  act.eventEmitter.on(NotificationAction.Events.Resolved, function (res) {
    t.equals(
      res,
      NotificationAction.ActionResolution.HTTP_BAD_RESPONSE,
      'Response should be HTTP_BAD_RESPONSE');
  });

  var keepAliveAgent = new http.Agent({ keepAlive: true });
  act.start(keepAliveAgent).then( function (res) {
    t.equals(res, null, 'must return null after successful call');
  }).catch(function (err) {
    t.fail('Test failed:' + err.message);
  });
});

test('Test NETWORK_PROBLEM locally', function (t) {

  t.plan(2);

  var connInfo = new PeerDictionary.PeerConnectionInformation(
    'address_that_cant_exists', 100, 2000);

  var act = new NotificationAction('hello',
    ThaliMobile.connectionTypes.TCP_NATIVE,
    globals.targetDeviceKeyExchangeObjects[0], addressBookCallback , connInfo);

  act.eventEmitter.on(NotificationAction.Events.Resolved, function (res) {
    t.equals(
      res,
      NotificationAction.ActionResolution.NETWORK_PROBLEM,
      'Response should be NETWORK_PROBLEM');
  });

  var keepAliveAgent = new http.Agent({ keepAlive: true });
  act.start(keepAliveAgent).then( function () {
    t.fail('This call should cause reject.');
  }).catch(function (err) {
    t.equals(
      err.message,
      'Could not establish TCP connection',
      'reject reason should be: Could not establish TCP connection');
  });
});

test('Test timeout locally', function (t) {

  t.plan(2);

  // Sets 3000 milliseconds delay for request handling.
  httpTester.runServer(globals.expressRouter, '/NotificationBeacons', 503,
    'hello', 1, 3000);

  // Sets 1000 milliseconds TCP timeout.
  var connInfo = new PeerDictionary.PeerConnectionInformation('127.0.0.1',
    globals.expressServer.address().port, 1000);

  var act = new NotificationAction('hello',
    ThaliMobile.connectionTypes.TCP_NATIVE,
    globals.targetDeviceKeyExchangeObjects[0], addressBookCallback , connInfo);

  act.eventEmitter.on(NotificationAction.Events.Resolved, function (res) {
    t.equals(
      res,
      NotificationAction.ActionResolution.NETWORK_PROBLEM,
      'Should be NETWORK_PROBLEM caused by timeout');
  });

  var keepAliveAgent = new http.Agent({ keepAlive: true });

  act.start(keepAliveAgent).then( function () {
    t.fail('This call should cause reject.');
  }).catch(function (err) {
    t.equals(
      err.message,
      'Could not establish TCP connection',
      'reject reason should be Could not establish TCP connection');
  });
});

test('Call the start two times', function (t) {

  t.plan(3);

  httpTester.runServer(globals.expressRouter,
    NotificationCommmon.NOTIFICATION_BEACON_PATH,
    200, globals.preambleAndBeacons, 1);

  var connInfo = new PeerDictionary.PeerConnectionInformation('127.0.0.1',
    globals.expressServer.address().port, 2000);

  var act = new NotificationAction('hello',
    ThaliMobile.connectionTypes.TCP_NATIVE,
    globals.targetDeviceKeyExchangeObjects[0], addressBookCallback , connInfo);

  act.eventEmitter.on(NotificationAction.Events.Resolved, function (res) {
    t.equals(
      res,
      NotificationAction.ActionResolution.BEACONS_RETRIEVED_AND_PARSED,
      'Response should be BEACONS_RETRIEVED_AND_PARSED');
  });

  var keepAliveAgent = new http.Agent({ keepAlive: true });
  var keepAliveAgent2 = new http.Agent({ keepAlive: true });

  act.start(keepAliveAgent).then( function (res) {
      t.equals(res, null, 'must return null after successful call.');
    })
    .catch(function (failure) {
      t.fail('Test failed:' + failure);
    });

  act.start(keepAliveAgent2).then( function () {
      t.fail('Second start should not be successful.');
    }).catch( function (err) {
    t.equals(err.message, ThaliPeerAction.DOUBLE_START, 'Call start once');
  });
});

test('Call the kill before calling the start', function (t) {

  t.plan(2);

  var connInfo = new PeerDictionary.PeerConnectionInformation('127.0.0.1',
    5000, 2000);

  var act = new NotificationAction('hello',
    ThaliMobile.connectionTypes.TCP_NATIVE,
    globals.targetDeviceKeyExchangeObjects[0], addressBookCallback, connInfo);

  act.eventEmitter.on(NotificationAction.Events.Resolved, function (res) {
    t.equals(res, NotificationAction.ActionResolution.KILLED,
      'Should be Killed');
  });
  act.kill();
  var keepAliveAgent = new http.Agent({ keepAlive: true });

  act.start(keepAliveAgent).catch( function (err) {
    t.equals(err.message, ThaliPeerAction.START_AFTER_KILLED,
      'Start after killed');
  });
});

test('Call the kill immediately after the start', function (t) {

  t.plan(2);

  // Sets 2000 milliseconds delay for request handling.
  httpTester.runServer(globals.expressRouter, '/NotificationBeacons', 503,
    'hello', 1, 2000);

  var connInfo = new PeerDictionary.PeerConnectionInformation('127.0.0.1',
    globals.expressServer.address().port, 1);

  var act = new NotificationAction('hello',
    ThaliMobile.connectionTypes.TCP_NATIVE,
    globals.targetDeviceKeyExchangeObjects[0], addressBookCallback , connInfo);

  act.eventEmitter.on(NotificationAction.Events.Resolved, function (res) {
    t.equals(
      res,
      NotificationAction.ActionResolution.KILLED,
      'Should be KILLED');
  });

  var keepAliveAgent = new http.Agent({ keepAlive: true });

  act.start(keepAliveAgent).then( function (res) {
      t.equals(res, null, 'must return null after successful kill');
    })
    .catch(function (failure) {
      t.fail('Test failed:' + failure);
    });

  act.kill();

});

test('Call the kill while waiting a response from the server', function (t) {

  t.plan(2);

  // Sets 10000 milliseconds delay for request handling.
  httpTester.runServer(globals.expressRouter, '/NotificationBeacons', 503,
    'hello', 1, 10000);

  // Sets 10000 milliseconds TCP timeout.
  var connInfo = new PeerDictionary.PeerConnectionInformation('127.0.0.1',
    globals.expressServer.address().port, 10000);

  var act = new NotificationAction('hello',
    ThaliMobile.connectionTypes.TCP_NATIVE,
    globals.targetDeviceKeyExchangeObjects[0], addressBookCallback , connInfo);

  act.eventEmitter.on(NotificationAction.Events.Resolved, function (res) {
    t.equals(
      res,
      NotificationAction.ActionResolution.KILLED,
      'Should be KILLED');
  });

  var keepAliveAgent = new http.Agent({ keepAlive: true });

  act.start(keepAliveAgent).then( function (res) {
    t.equals(
      res,
      null,
      'must return null after successful kill');
  }).catch(function (err) {
    t.fail('Test failed:' + err);
  });

  // This kills the action after 2 seconds. This should give enough time to
  // establish a HTTP connection in slow devices but since the server waits
  // 10 seconds before it answers we end up killing the connection when the
  // client is waiting the server to answer.

  setTimeout( function () {
    act.kill();
  }, 2000);

});


test('Test to exceed the max content size locally', function (t) {

  t.plan(2);

  var buffer = new Buffer(1000);
  buffer.fill('h');

  httpTester.runServer(globals.expressRouter,
    NotificationCommmon.NOTIFICATION_BEACON_PATH,
    200, buffer, NotificationAction.MAX_CONTENT_SIZE/1000);

  var connInfo = new PeerDictionary.PeerConnectionInformation('127.0.0.1',
    globals.expressServer.address().port, 1000);

  var act = new NotificationAction('hello',
    ThaliMobile.connectionTypes.TCP_NATIVE,
    globals.targetDeviceKeyExchangeObjects[0], addressBookCallback , connInfo);

  act.eventEmitter.on(NotificationAction.Events.Resolved, function (res) {
    t.equals(
      res,
      NotificationAction.ActionResolution.HTTP_BAD_RESPONSE,
      'HTTP_BAD_RESPONSE should be response when content size is exceeded');
  });

  var keepAliveAgent = new http.Agent({ keepAlive: true });
  act.start(keepAliveAgent).then( function (res) {
    t.equals(res, null, 'must return null after successful call');
  }).catch(function (failure) {
    t.fail('Test failed:' + failure);
  });
});