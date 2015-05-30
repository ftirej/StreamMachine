SlaveMode   = $src "modes/slave"

StreamListener  = $src "util/stream_listener"
MasterHelper    = require "./helpers/master"

debug = require("debug")("sm:tests:slave")



describe "Slave Mode", ->
    slave_config =
        slave:
            master: "FILLED_IN_BELOW"
        port:       0
        cluster:    2
        log:
            stdout: true

    slave_port  = null
    slave       = null
    master_info = null

    before (done) ->
        # unfortunately, to test slave mode, we need a master. that means
        # we get to do a lot here that hopefully gets tested elsewhere

        MasterHelper.startMaster "mp3", (err,info) ->
            throw err if err
            master_info = info

            debug "started master. Connect at: #{master_info.slave_uri}"
            debug "Stream Key is #{master_info.stream_key}"

            done()

    it "can start up", (done) ->
        this.timeout 10*1000
        slave_config.slave.master = master_info.slave_uri

        new SlaveMode slave_config, (err,s) ->
            throw err if err

            slave = s

            slave.once "full_strength", ->
                slave_port = slave._lastAddress.port
                expect(slave_port).to.not.be.undefined
                expect(slave_port).to.be.number
                done()

    it "has the correct number of listening workers", (done) ->
        expect(Object.keys(slave.lWorkers).length).to.eql slave_config.cluster
        done()

    it "has our stream information in all workers", (done) ->
        this.timeout 4000
        slave.status (err,status) ->
            debug "status got ", err, status
            throw err if err

            # expect two workers
            expect(Object.keys(status)).to.have.length 2

            for id,w of status
                expect(w.streams).to.have.key master_info.stream_key
                expect(w.streams[ master_info.stream_key ].buffer_length).to.eql 0

            done()

    describe "Server", ->
        it "can accept a raw listener", (done) ->
            listener = new StreamListener "127.0.0.1", slave_port, master_info.stream_key

            listener.connect (err) =>
                throw err if err
                listener.disconnect()
                done()

        it "can accept a Shoutcast listener", (done) ->
            listener = new StreamListener "127.0.0.1", slave_port, master_info.stream_key, true

            listener.connect (err) =>
                throw err if err
                listener.disconnect()
                done()

        it "gives a 404 for a bad stream path", (done) ->
            listener = new StreamListener "127.0.0.1", slave_port, "invalid", true

            listener.connect (err) =>
                expect(err).to.not.be.null
                done()

    describe "Worker Control", ->
        it "can ask a worker for its handle", (done) ->
            slave._getHandleFromWorker (err,handle) ->
                throw new Error err if err
                done()

        it "can shut down a worker on request", (done) ->
            # get a worker id to shut down
            id = Object.keys(slave.workers)[0]
            worker = slave.workers[id]

            slave.shutdownWorker id, (err) ->
                throw err if err

                # expect worker process to be shut down
                try
                    # signal 0 tests whether process exists
                    process.kill worker.pid, 0

                    # if we get here we've failed
                    throw new Error "Process should not exist."
                catch e
                    expect(e.code).to.eql "ESRCH"

                # export slave.workers to no longer include this worker
                expect(slave.workers).to.not.include.keys id

                done()

        it "should spawn a replacement worker", (done) ->
            this.timeout 5000
            slave.once "worker_listening", ->
                expect(Object.keys(slave.workers)).to.have.length slave_config.cluster
                done()
