# A2b report - ports + storage buffers
Branch: a2b-port-link (from c037bec, not pushed). Files: sim/logistics/port_link.gd (PortLink), tests/test_ports.gd (5 tests).
Hooks (one line each, region A2b): LogisticsSystem.tick() calls PortLink.tick(sim) before belts.step(); Building.input_space() delegates port buildings to PortLink.manual_input_space.
(item_system.gd was not needed: buffers live in Building.input/output, existing haul giver already moves them.)
Geometry: belt cell = building.cell + (port.dx, port.dy). Out port: belt there, empty, not pointing back into the building -> inserts 1 item/tick max.
In port: belt there has a READY item and points into the building, building accepts -> take_ready, accept. Buildings in id order; skips broken/destroyed.
storage_in: belt -> `output` buffer (cap buffer_capacity=200 total); colonists haul it to a zone via haul giver step 1 (BUILDING_OUT).
storage_out: colonists haul ground items into `input` (input_space = 200 - total) via giver step 2; its port drains it to the belt.
Machine interface (A2a): optional duck-typed methods on Building/Machine, else defaults:
  port_accepts(item)->bool, port_accept(item)->bool, port_peek()->String, port_take(item)->bool.
  Defaults: in = input_space/add_input(item,1); out = first sorted key of `output` -> take_output(item,1).
Full suite: 360 pass, 6 fail = exactly the baseline six.
Notes: items on belts are not in ItemSystem.count_world (A2e may add). A1d place_belt dirs (0=E..) differ from BeltGrid dirs (0=N); PortLink uses BeltGrid dirs via belt_dir().
