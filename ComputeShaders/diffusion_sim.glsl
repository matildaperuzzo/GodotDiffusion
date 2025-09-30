#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

layout(r32f, binding = 0) uniform image2D geo_texture;

layout(r8, binding = 1) uniform image2D simulation_texture;

layout(std430, set = 0, binding = 2) restrict buffer Params {
    int seed;
} params;

layout (r8, binding = 3) uniform image2DArray simulation_texture_array;

uint hash(uint state)
{
    state ^= 2747636419u;
    state *= 2654435769u;
    state ^= state >> 16;
    state *= 2654435769u;
    state ^= state >> 16;
    state *= 2654435769u;
    return state;
}

float scaleToRange01(uint state)
{
    return state / 4294967295.0;
}

void main() {
    // extract texture size
    int ind_x = int(gl_GlobalInvocationID.x);
    int ind_y = int(gl_GlobalInvocationID.y);
    int ind_z = int(gl_GlobalInvocationID.z);
    int n_av = int(gl_NumWorkGroups.z * gl_WorkGroupSize.z);
    ivec3 SIM_SIZE = ivec3(gl_WorkGroupSize);
    ivec2 texture_size = imageSize(geo_texture);
    
    // find pixel color
    if (ind_x < texture_size.x && ind_y < texture_size.y) {
        // Calculate the pixel coordinates
        ivec3 pixel_coords = ivec3(ind_x, ind_y, ind_z);
        ivec2 pixel_coords_2d = ivec2(ind_x, ind_y);
        // Read the color from the geo_texture
        vec4 sim_color = imageLoad(simulation_texture_array, pixel_coords);

        if (sim_color.r == 0.0) {
            // check if any neighbour is not white
            ivec3 neighbour_coords[4] = {
                pixel_coords + ivec3(1, 0, 0),   // right
                pixel_coords + ivec3(-1, 0, 0),  // left
                pixel_coords + ivec3(0, 1, 0),   // down
                pixel_coords + ivec3(0, -1, 0)    // up
            };
            bool has_active_neighbour = false;
            for (int i = 0; i < 4; i++) {
                // skip if neighbour is outside of picture
                if (neighbour_coords[i].x < 0 || neighbour_coords[i].x >= texture_size.x ||
                    neighbour_coords[i].y < 0 || neighbour_coords[i].y >= texture_size.y) {
                    continue;
                }
                vec4 neighbour_color = imageLoad(simulation_texture_array, neighbour_coords[i]);
                if (neighbour_color.r == 1.0) {
                    has_active_neighbour = true;
                    break;
                }
            }

            if (has_active_neighbour) {
                uint flat_index = ind_x + ind_y * SIM_SIZE.x + ind_z * SIM_SIZE.x * SIM_SIZE.y;
                float random_num = scaleToRange01(hash(flat_index + params.seed));
                float geo_value = imageLoad(geo_texture, pixel_coords_2d).r;

                if (random_num < geo_value) {
                    imageStore(simulation_texture_array, pixel_coords, vec4(1.0, 1.0, 1.0, 1.0));
                }
            }
            
            float av_simulation_value = imageLoad(simulation_texture, pixel_coords_2d).r;
            av_simulation_value += imageLoad(simulation_texture_array, pixel_coords).r / float(n_av);

            imageStore(simulation_texture, pixel_coords_2d, vec4(av_simulation_value, av_simulation_value, av_simulation_value, 1.0));
        }
    }


}