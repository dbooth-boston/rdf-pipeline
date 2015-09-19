var graph = new joint.dia.Graph;

var paper = new joint.dia.Paper({
    el: $('#paper'),
    width: 800,
    height: 600,
    gridSize: 1,
    model: graph
});

var connect = function(source, sourcePort, target, targetPort) {
    var link = new joint.shapes.devs.Link({
        source: { id: source.id, selector: source.getPortSelector(sourcePort) },
        target: { id: target.id, selector: target.getPortSelector(targetPort) }
    });
    graph.addCell(link);
};

var node = function(label, options) {

	var atomic = joint.shapes.devs.Model.extend({
	    defaults: joint.util.deepSupplement({
		type: 'devs.Atomic',
		size: { width: 80, height: 80 },
		attrs: {
		    '.body': { fill: 'salmon' },
		    '.label': { text: label },
		    '.inPorts .port-body': { fill: 'PaleGreen' },
		    '.outPorts .port-body': { fill: 'Tomato' }
		}
	    }, joint.shapes.devs.Model.prototype.defaults)
	});

	return new atomic(options);
};

var a1 = new node('a1', {
    position: { x: 360, y: 360 },
    inPorts: ['a1.in'],
    outPorts: ['a1.out1','a1.out2']
});

var a2 = new joint.shapes.devs.Atomic({
    position: { x: 50, y: 260 },
    outPorts: ['a2.out']
});

var a3 = new joint.shapes.devs.Atomic({
    position: { x: 650, y: 150 },
    size: { width: 100, height: 300 },
    inPorts: ['a','b']
});

graph.addCell(a1).addCell(a2).addCell(a3);

connect(a2,'a2.out',a1,'a1.in');
connect(a1,'a1.out1',a3,'a');
connect(a1,'a1.out2',a3,'b');

