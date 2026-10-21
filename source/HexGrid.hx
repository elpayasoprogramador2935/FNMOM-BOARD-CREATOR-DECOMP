package;

typedef Cell = {n:Int, m:Int};

class HexGrid
{
	var h:Float;
	var v:Float;

	public function new(tile:BoardTile)
	{
		h = tile.stepX();
		v = tile.stepY();
	}

	public function centerX(cell:Cell):Float
	{
		return cell.n * h;
	}

	public function centerY(cell:Cell):Float
	{
		return cell.m * v + cell.n * v / 2;
	}

	public function cellAt(x:Float, y:Float):Cell
	{
		var col = Math.round(x / h);
		var best:Cell = null;
		var bestDist = Math.POSITIVE_INFINITY;

		for (n in col - 1...col + 2)
		{
			var cell:Cell = {n: n, m: Math.round(y / v - n / 2)};
			var dx = x - centerX(cell);
			var dy = y - centerY(cell);
			var dist = dx * dx + dy * dy;

			if (dist < bestDist)
			{
				best = cell;
				bestDist = dist;
			}
		}
		return best;
	}

	public static function line(from:Cell, to:Cell):Array<Cell>
	{
		var dn = to.n - from.n;
		var dm = to.m - from.m;
		var steps = Std.int((Math.abs(dn) + Math.abs(dm) + Math.abs(dn + dm)) / 2);

		return [for (i in 1...steps + 1) round(from.n + dn * i / steps, from.m + dm * i / steps)];
	}

	static function round(n:Float, m:Float):Cell
	{
		var s = -n - m;
		var rn:Float = Math.round(n);
		var rm:Float = Math.round(m);
		var rs:Float = Math.round(s);
		var dn = Math.abs(rn - n);
		var dm = Math.abs(rm - m);
		var ds = Math.abs(rs - s);

		if (dn > dm && dn > ds)
			rn = -rm - rs;
		else if (dm > ds)
			rm = -rn - rs;

		return {n: Std.int(rn), m: Std.int(rm)};
	}
}
