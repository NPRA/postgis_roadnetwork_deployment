CREATE OR REPLACE FUNCTION npra_routing_getroute(startpoint text, endpoint text) 
RETURNS text
AS
	$result$
BEGIN 
	RETURN (
		SELECT st_astext(res.route)
		FROM (
			WITH start AS (
			  SELECT topo.fromnode as source
			  FROM ruttger_link_geom as topo
			  ORDER BY topo.shape <-> ST_Transform(ST_GeometryFromText(startpoint,4326),25833)
			  LIMIT 1),
			destination AS (
			  SELECT (CASE WHEN (SELECT source FROM start) = topo.tonode  THEN topo.fromnode ELSE topo.tonode END) as source
			  FROM ruttger_link_geom as topo
			  ORDER BY topo.shape <-> ST_Transform(ST_GeometryFromText(endpoint,4326),25833)
			  LIMIT 1)
			-- use Dijsktra and join with the geometries
			SELECT ST_Union(shape) as route
			FROM pgr_dijkstra('
				SELECT linkid as id, fromnode as source, tonode as target, drivetime_fw as cost, drivetime_bw as reverse_cost
					FROM ruttger_link_geom as e,
				(SELECT ST_Expand(ST_Extent(b.shape),100) as box FROM ruttger_link_geom as b
					WHERE b.fromnode = '|| (SELECT source FROM start) ||'
					OR b.fromnode = ' || (SELECT source FROM destination) || ') as box WHERE e.shape && box.box'
				,
				array(SELECT source FROM start),
				array(SELECT source FROM destination),
				directed := false) AS di
			JOIN   ruttger_link_geom AS pt
			  ON   di.edge = pt.linkid)	as res
		);
END;
	$result$
LANGUAGE plpgsql
