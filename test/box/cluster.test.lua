fiber = require('fiber')
test_run = require('test_run').new()
fio = require('fio')

test_run:cmd("setopt delimiter ';'")
function create_script(name, code)
    local path = fio.pathjoin(fio.tempdir(), name)
    local script = fio.open(path, {'O_CREAT', 'O_WRONLY'},
        tonumber('0777', 8))
    assert(script ~= nil, ("assertion: Failed to open '%s' for writing"):format(path))
    script:write(code)
    script:close()
    return path
end;

code_template = "box.cfg{ listen = %s, server_id = %s } "..
		"box.schema.user.grant('guest', 'read,write,execute', 'universe') "..
		"space = box.schema.space.create('test', { engine = 'vinyl' })"..
		"pk = space:create_index('primary')"..
		"require('console').listen(os.getenv('ADMIN'))";
test_run:cmd("setopt delimiter ''");

tmp1 = create_script('host1.lua', code_template:format(33130, 1))
tmp2 = create_script('host2.lua', code_template:format(33131, 2))
tmp3 = create_script('host3.lua', code_template:format(33132, 3))

--
-- Create shard instances.
--

test_run:cmd(("create server host1 with script='%s'"):format(tmp1))
test_run:cmd(("create server host2 with script='%s'"):format(tmp2))
test_run:cmd(("create server host3 with script='%s'"):format(tmp3))

test_run:cmd("start server host1")
test_run:cmd("start server host2")
test_run:cmd("start server host3")

--
-- Connect one to each other.
--

---------------- Host 1 ----------------

test_run:cmd('switch host1')
fiber = require('fiber')
test_run:cmd("setopt delimiter ';'")

box.cfg{
	cluster = {
		shard1 = { uri = 'localhost:33130' },
		shard2 = { uri = 'localhost:33131' },
		shard3 = { uri = 'localhost:33132' },
	}
};

test_run:cmd("setopt delimiter ''");

box.cfg.server_id == box.info.server.id
box.cfg.server_id
box.cfg.cluster.shard1.state
box.cfg.cluster.shard2.state
box.cfg.cluster.shard3.state

---------------- Host 2 ----------------

test_run:cmd('switch host2')
test_run:cmd("setopt delimiter ';'")

box.cfg{
	cluster = {
		shard1 = { uri = 'localhost:33130' },
		shard2 = { uri = 'localhost:33131' },
		shard3 = { uri = 'localhost:33132' },
	}
};

test_run:cmd("setopt delimiter ''");

box.cfg.server_id == box.info.server.id
box.cfg.server_id
box.cfg.cluster.shard1.state
box.cfg.cluster.shard2.state
box.cfg.cluster.shard3.state

---------------- Host 3 ----------------

test_run:cmd('switch host3')
test_run:cmd("setopt delimiter ';'")

box.cfg{
	cluster = {
		shard1 = { uri = 'localhost:33130' },
		shard2 = { uri = 'localhost:33131' },
		shard3 = { uri = 'localhost:33132' },
	}
};

test_run:cmd("setopt delimiter ''");

box.cfg.server_id == box.info.server.id
box.cfg.server_id
box.cfg.cluster.shard1.state
box.cfg.cluster.shard2.state
box.cfg.cluster.shard3.state

---------------- Make two-phase transaction ----------------

test_run:cmd('switch host1')

cluster = box.cfg.cluster
cluster.shard1:begin_two_phase()
cluster.shard2:begin_two_phase()
cluster.shard3:begin_two_phase()

cluster.shard1.space.test:replace({1})
cluster.shard2.space.test:replace({2})
cluster.shard3.space.test:replace({3})

box.space._transaction:select{}
cluster.shard1:prepare()
box.space._transaction:select{}
cluster.shard2:prepare()
box.space._transaction:select{}
cluster.shard3:prepare()
box.space._transaction:select{}

cluster.shard1:commit()
cluster.shard2:commit()
cluster.shard3:commit()

cluster.shard1.space._transaction:select{}
cluster.shard2.space._transaction:select{}
cluster.shard3.space._transaction:select{}
cluster.shard1.space.test:select{}
cluster.shard2.space.test:select{}
cluster.shard3.space.test:select{}

---------------- Fail prepare of two phase transaction ----------------

cluster.shard3.space.test:replace({6})

cluster.shard1:begin_two_phase()
cluster.shard2:begin_two_phase()
cluster.shard3:begin_two_phase()

cluster.shard1.space.test:replace({4})
cluster.shard2.space.test:replace({5})
cluster.shard3.space.test:update({6}, {{'!', 2, 6}})

-- Implicitly abort the subtransaction on the shard3.
f = fiber.create(function() cluster.shard3.space.test:replace({6, 6, 6}) end)
while f:status() ~= 'dead' do fiber.yield() end

cluster.shard1:prepare()
cluster.shard2:prepare()
status, err = pcall(cluster.shard3.prepare, cluster.shard3) -- must fail
status
err

cluster.shard1:rollback()
cluster.shard2:rollback()
-- cluster.shard3:rollback() -- already aborted.

cluster.shard1.space._transaction:select{}
cluster.shard2.space._transaction:select{}
cluster.shard3.space._transaction:select{}
cluster.shard1.space.test:select{}
cluster.shard2.space.test:select{}
cluster.shard3.space.test:select{}

--
-- Test recovery of two-phase transaction after restart of the
-- participant in the middle of the transaction.
--

-- Recovery the commited transaction.

cluster.shard1:begin_two_phase()
cluster.shard2:begin_two_phase()
cluster.shard3:begin_two_phase()

cluster.shard1.space.test:replace({7})
cluster.shard2.space.test:replace({8})
cluster.shard3.space.test:replace({9})

cluster.shard1:prepare()
cluster.shard2:prepare()
cluster.shard3:prepare()

cluster.shard1:commit()
cluster.shard2:commit()

test_run:cmd('restart server host3')
test_run:cmd('switch host1')
-- After restarting, the host3 get the transaction state from the
-- coordinator. Using presumed commit, the coordinator doesn't
-- store the state of the transaction and it supposed to be
-- commited.
cluster.shard1.space.test:select{}
cluster.shard2.space.test:select{}
cluster.shard3.space.test:select{}


test_run:cmd("stop server host1")
test_run:cmd("cleanup server host1")
test_run:cmd("stop server host2")
test_run:cmd("cleanup server host2")
test_run:cmd("stop server host3")
test_run:cmd("cleanup server host3")
