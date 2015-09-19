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

var c1 = new joint.shapes.devs.Coupled({
    position: { x: 260, y: 150 },
    size: { width: 300, height: 300 },
    inPorts: ['in'],
    outPorts: ['out 1','out 2']
});

var a1 = new joint.shapes.devs.Atomic({
    position: { x: 360, y: 360 },
    inPorts: ['port XY'],
    outPorts: ['x','y']
});

var a2 = new joint.shapes.devs.Atomic({
    position: { x: 50, y: 260 },
    outPorts: ['out']
});

var a3 = new joint.shapes.devs.Atomic({
    position: { x: 650, y: 150 },
    size: { width: 100, height: 300 },
    inPorts: ['a','b']
});

graph.addCell(c1).addCell(a1).addCell(a2).addCell(a3);

c1.embed(a1);

connect(a2,'out',c1,'in');
connect(c1,'in',a1,'port XY');
connect(a1,'x',c1,'out 1');
connect(a1,'y',c1,'out 2');
connect(c1,'out 1',a3,'a');
connect(c1,'out 2',a3,'b');

