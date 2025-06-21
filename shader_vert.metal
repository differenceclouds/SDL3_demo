#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
};

vertex VertexOut vertex_main(uint vertex_id [[vertex_id]])
{
    VertexOut out;
    if (vertex_id == 0) {
    	out.position = float4(-0.5, -0.5, 0, 1);
    } else if (vertex_id == 1) {
    	out.position = float4(0, 0.5, 0, 1);
    } else if (vertex_id == 2) {
    	out.position = float4(0.5, -0.5, 0, 1);
    }
    return out;
}