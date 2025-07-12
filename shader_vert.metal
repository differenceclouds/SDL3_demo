#include <metal_stdlib>
using namespace metal;

// layout(set=1, binding=0) uniform UBO {
//     mat4 proj;
// }

// struct UBO {
//     float4x4 proj; // Metal uses float4x4 for 4x4 matrices
// };

// // Declare the uniform buffer
// uniform UBO ubo [[buffer(0)]]; // Use buffer index 0

// Example function that uses the uniform buffer
// vertex void myVertexFunction(..., constant UBO& ubo [[buffer(0)]]) {
//     // Use ubo.proj here
// }


struct VertexOut {
    float4 position [[position]];
};

vertex VertexOut vertex_main(uint vertex_id [[vertex_id]])
{
    VertexOut out;
    if (vertex_id == 0) {
    	out.position = float4(-0.5, -0.5, -5, 1);
    } else if (vertex_id == 1) {
    	out.position = float4(0, 0.5, -5, 1);
    } else if (vertex_id == 2) {
    	out.position = float4(0.5, -0.5, -5, 1);
    }
    return out;
}