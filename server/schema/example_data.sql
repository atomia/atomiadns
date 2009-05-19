SELECT CreateZone('sigint.se', 3600, 'ns1.loopia.se.', 'registry.loopia.se.', 10800, 3600, 604800, 86400, ARRAY['ns1.loopia.se.', 'ns2.loopia.se.']);
SELECT AddDnsRecords('sigint.se', ARRAY[ARRAY['-1', 'www', 'IN', '3600', 'A', '127.0.0.1'], ARRAY['-1', '*', 'IN', '60', 'A', '127.0.0.2']]);
