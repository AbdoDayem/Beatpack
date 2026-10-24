@import "chodash"

// Fix Textures
TextureLoadDesc loadDesc;
true => loadDesc.flip_y;
false => loadDesc.gen_mips;
GWindow.fullscreen();

TextureSampler.nearest() @=> TextureSampler pixel;
TextureSampler.Filter_Nearest => pixel.filterMin; 
TextureSampler.Filter_Nearest => pixel.filterMag; 

5 => int NUM_INSTRUMENTS;

// -------------------------------------------------------------------//
// Classes //
// Item Shapes & Textures
[ 
    [0, 0, 0],
    [0, 1, 0],
    [0, 0, 0]
] @=> int activator_shape[][];
Texture.load(me.dir() + "./data/textures/activator.png", loadDesc) @=> Texture activator_tex;

[ 
    [0, 1, 0],
    [0, 1, 1],
    [0, 0, 0]
] @=> int drum_shape[][];
Texture.load(me.dir() + "./data/textures/drums.png", loadDesc) @=> Texture drum_tex;

[ 
    [0, 0, 0],
    [0, 1, 0],
    [1, 0, 0]
] @=> int guitar_shape[][];
Texture.load(me.dir() + "./data/textures/guitar.png", loadDesc) @=> Texture guitar_tex;

[ 
    [0, 0, 0],
    [0, 1, 0],
    [1, 0, 0]
] @=> int trumpet_shape[][];
Texture.load(me.dir() + "./data/textures/trumpet.png", loadDesc) @=> Texture trumpet_tex;

[ 
    [0, 0, 0],
    [0, 1, 0],
    [0, 0, 0]
] @=> int snare_shape[][];
Texture.load(me.dir() + "./data/textures/snare.png", loadDesc) @=> Texture snare_tex;

[ 
    [0, 0, 0],
    [0, 1, 0],
    [0, 0, 0]
] @=> int cymbal_shape[][];
Texture.load(me.dir() + "./data/textures/cymbal.png", loadDesc) @=> Texture cymbal_tex;

// shapes
int shapes[0][3][3];
shapes << drum_shape;
shapes << guitar_shape;
shapes << trumpet_shape;
shapes << cymbal_shape;
shapes << snare_shape;
shapes << activator_shape;

// textures
Texture textures[0];
textures << drum_tex;
textures << guitar_tex;
textures << trumpet_tex;
textures << cymbal_tex;
textures << snare_tex;
textures << activator_tex;

// sounds
string samples[0];
samples << me.dir() + "./data/samples/drums.wav";
samples << me.dir() + "./data/samples/guitar.wav";
samples << me.dir() + "./data/samples/trumpet.wav";
samples << me.dir() + "./data/samples/cymbal.wav";
samples << me.dir() + "./data/samples/snare.wav";
samples << me.dir() + "./data/samples/activator.wav";

// Item/Instrument/Sample
class Item extends GGen
{
    int shape[3][3];         // Item Shape (3x3)
    GPlane plane;            // Actual GGen
    FlatMaterial mat;        // Texture stuff
    vec2 base_pos;           // return position;
    int snap_state; 
    int snap_pos[2];
    Grid @ grid;
    int direction; // 0 up, 1 right, 2 down, 3 left
    int playing;
    SndBuf buf => dac;

    // i dont know why theres 2 constructors, but brenden did this and it fixed the bug
    fun construct(Texture tex, int shape_[][])
    {
        mat.colorMap(tex);
        mat.sampler(pixel);
        plane.material(mat);
        shape_ @=> shape;
        plane --> this;
        @(0,0) => base_pos;
        0 => snap_state;
    }

    fun @construct(Texture tex, int shape_[][])
    {
        construct(tex, shape_);
    }

    fun setBase(vec2 new_pos)
    {
        new_pos => base_pos;
    }

    fun void loadSample(string path)
    {
        0.3 => buf.gain;
        path => buf.read;
        buf.samples() => buf.pos;
    }

    fun void rotate()
    {
        direction + 1 => direction;
        if (direction == 4) {0 => direction;}
        int new_shape[3][3];
        for(int i; i < 3; i++)
        {
            for(int j; j < 3; j++)
            {
                shape[2-j][i] => new_shape[i][j];
            }
        }
        new_shape @=> shape;
    }

    fun void play()
    {
        if(playing) return;
        0 => buf.pos;
        1 => playing;
        TweenAnimation ItemScale;
        ItemScale.add(Tween.scale(this, 1.5, 0.25::second, TweenEase.IN_OUT_SINE).yoyo());
        Tween.play(ItemScale);
        spork ~ resetScale();
    }

    // so when 2 activators activate same item it doesnt stay perma big
    fun void resetScale()
    {
        0.49::second => now;
        this.sca(1.0);
        0 => playing;
    }
}

class Activator extends Item
{
    Slot @ mySlot;

    fun @construct(Texture tex, int shape_[][])
    {
        null => mySlot;
        super.construct(tex, shape_);
        0 => direction;
    }

    fun void activate()
    {
        this.grid @=> Grid g;
        if(g == null) return;

        snap_pos[0] => int row;
        snap_pos[1] => int col;
        direction => int dir;

        for(int a; a < g.side_len; a++)
        {
            int i;
            int j;
            if(dir == 0)
            {
                row - a => i;
                if(i < 0) { i + g.side_len => i; }
                col => j;
            } else if (dir == 1)
            {
                row => i;
                col + a => j;
                if(j >= g.side_len) { j - g.side_len => j; }
            } else if (dir == 2)
            {
                row + a => i;
                if(i >= g.side_len) { i - g.side_len => i; }
                col => j;
            } else if (dir == 3)
            {
                row => i;
                col - a => j;
                if(j < 0) { j + g.side_len => j;}
            }

            if(g.slots[i][j] != null && g.slots[i][j].held != null)
            {
                g.slots[i][j].held.play();
            }
            0.5::second => now;

            // to stop null pointer exception if i pick it up mid activate
            if(grid != g) 
            {
                0.5::second => now; // wait for the current play spork to end
                return;
            }
        }
    }
}

// Backpack Slot
class Slot extends GGen
{
    GPlane plane;
    FlatMaterial mat;
    Texture.load(me.dir() + "./data/textures/slot.png", loadDesc) @=> Texture baset;
    Texture.load(me.dir() + "./data/textures/snapped.png", loadDesc) @=> Texture snapt;
    Item @ held; // Current held item
    Grid @ grid;

    // Constructor
    fun @construct()
    {
        null => held;
        mat.colorMap(baset);
        mat.sampler(pixel);
        plane.material(mat);
        plane --> this;
    }

    fun void snap(Item item)
    {
        item @=> held;
        if(item )
        mat.colorMap(snapt);
        plane.material(mat);
    }

    fun void desnap()
    {
        null => held;
        mat.colorMap(baset);
        plane.material(mat);
    }
}

// Backpack Shapes 
// Ideally Square and Odd Lengthed
[ 
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1],    
] @=> int shape0[][];

[ 
    [1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1],  
] @=> int shape1[][];

[ 
    [0, 1, 1, 1, 0],
    [1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1],
    [0, 1, 1, 1, 0], 
] @=> int shape2[][];

[ 
    [0, 1, 1, 1, 0],
    [1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1],
    [0, 0, 0, 0, 0], 
] @=> int shape3[][];

[ 
    [1, 1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1],  
    [1, 1, 1, 1, 1, 1, 1]
] @=> int shape4[][];

// Backpack Grid
class Grid extends GGen
{
    Slot slots[][];         // actual slots
    int shape[][];          // backpack shape
    int side_len;           // backpack side length
    0.32 => float SLOT_GAP; // gap between slot centers
    0 => float SLOT_SHIFT;  // handles even grid sizes
    1 => float scal;        // scale
    0 => float x;           // x pos
    0 => float y;           // y pos
    GPlane plane;
    FlatMaterial mat;
    Texture.load(me.dir() + "./data/textures/bag.png", loadDesc) @=> Texture tex;

    // Constructor
    fun @construct(int shape_[][])
    {
        mat.colorMap(tex);
        mat.sampler(pixel);
        plane.material(mat);
        plane --> this;
        plane --> GG.scene();
        plane.sca(5.0);
        plane.pos(@(x - (0.07 * 5 * scal), y - (0.04 * 5 * scal)));

        shape_.size() => side_len;
        new Slot[side_len][side_len] @=> slots;
        shape_ @=> shape;
        for(int i; i < side_len; i++)
        {
            new Slot[side_len] @=> slots[i];
            for(int j; j < side_len; j++)
            {
                if(shape[i][j] == 1)
                {
                    new Slot @=> Slot slot;
                    slot @=> slots[i][j];
                    if(side_len % 2 == 0) SLOT_GAP/2 => SLOT_SHIFT;
                    slot.posWorld(@((j - side_len/2)*SLOT_GAP + SLOT_SHIFT, (-i + side_len/2)*SLOT_GAP - SLOT_SHIFT));
                    slot --> GG.scene();
                    this @=> slot.grid;
                }
            }
        }
    }

    fun void snapOff(Item item)
    {
        0 => item.snap_state;
        null @=> item.grid;
        for(int n; n < 3; n++ )
        {
            for(int m; m < 3; m++ )
            {
                if(item.shape[n][m] == 1)
                    {
                        slots[item.snap_pos[0]+n-1][item.snap_pos[1]+m-1].desnap();
                    }
            }
        }
    }

    // Snap item on grid
    // just dont ask
    fun void snapOn(Item item)
    {
        for(int i; i < side_len; i++)
        {
            for(int j; j < side_len; j++)
            {
                if(isHovered(item, slots[i][j].pos()))
                {
                    1 => int pass_check;
                    for(int n; n < 3; n++ )
                    {
                        for(int m; m < 3; m++ )
                        {
                            if(item.shape[n][m] == 1)
                            {
                                if(
                                ((i+n-1) >= side_len) ||
                                ((i+n-1) < 0) ||
                                ((j+m-1) >= side_len) ||
                                ((j+m-1) < 0) ||
                                slots[i+n-1][j+m-1].held != null)
                                {
                                    0 => pass_check;
                                }
                            }
                        }
                    }

                    if(pass_check)
                    {
                        for(int n; n < 3; n++ )
                        {
                            for(int m; m < 3; m++ )
                            {
                                if(item.shape[n][m] == 1)
                                {
                                    slots[i+n-1][j+m-1].snap(item);
                                }
                            }
                        }
                        item.pos(slots[i][j].pos());
                        i => item.snap_pos[0];
                        j => item.snap_pos[1];
                        1 => item.snap_state;
                        this @=> item.grid;
                        return;
                    } else {
                        item.pos(item.base_pos);
                        return;
                    }
                }
            }
        }
    }

    // Custom scale function to keep grid (kind of) centered
    fun void scale(float sscale)
    {
        sscale => scal;
        plane.sca(5 * scal);
        this.position(x, y);
        for(int i; i < side_len; i++)
        {
            for(int j; j < side_len; j++)
            {
                if(shape[i][j] == 1)
                {
                    slots[i][j].sca(scal);
                }
            }
        }
    }

    // Custom position function
    fun void position(float xx, float yy)
    {
        xx => x;
        yy => y;
        plane.pos(@(x - (0.07 * 5 * scal), y - (0.04 * 5 * scal)));
        for(int i; i < side_len; i++)
        {
            for(int j; j < side_len; j++)
            {
                if(shape[i][j] == 1)
                {
                    slots[i][j].posWorld(@((j - side_len/2)*scal*SLOT_GAP  + SLOT_SHIFT + x, (-i + side_len/2)*scal* SLOT_GAP - SLOT_SHIFT + y));
                }
            }
        }
    }
}
// -------------------------------------------------------------------//
// Helpers //
// Spawns items on generators
fun void spawnAt(int i)
{
    Math.random2(0, NUM_INSTRUMENTS) => int r;
    Item @ new_item;

    if(r == NUM_INSTRUMENTS)
    {
        new Activator(textures[r], shapes[r]) @=> Activator act;
        activate_command.addActivator(act);
        act @=> new_item;
    }
    else
    {
        new Item(textures[r], shapes[r]) @=> new_item;
    }

    new_item.loadSample(samples[r]);
    new_item --> GG.scene();
    new_item.pos(generators[i].pos());
    new_item.posZ(0.01);
    new_item.setBase(@(generators[i].posX(), generators[i].posY()));
    cur_item << new_item;
    new_item @=> stock[i];
}

// Ripped off from cheatsheet
// returns true if mouse is hovering over the plane
fun int isHovered(GGen plane, vec3 mouse_pos) {
    plane.scaWorld() => vec3 worldScale;        // get dimensions
    worldScale.x / 4.0 => float halfWidth;      // divide by 2 for half, divide by 3 again to get center 32x32 segment of item
    worldScale.y / 4.0 => float halfHeight;
    plane.pos() => vec3 worldPos;               // get position

    if 
    (
    mouse_pos.x > worldPos.x - halfWidth 
    && 
    mouse_pos.x < worldPos.x + halfWidth 
    && 
    mouse_pos.y > worldPos.y - halfHeight 
    && 
    mouse_pos.y < worldPos.y + halfHeight
    ) 
    {
        return true;
    }
    return false;
}

public class RotateCommand extends KeyboardCommand
{
    Item @ item;
    fun @construct()
    {
        super.init("rotate");
    }

    fun void setItem(Item item){
        item @=> this.item;
    }

    fun void run()
    {
        if (item != null) 
        {
            TweenAnimation ItemRotation;
            ItemRotation.add(Tween.rotateBy(item, @(0, 0, Math.PI/2), 0.25::second, TweenEase.IN_OUT_SINE));
            item.rotate();
            Tween.play(ItemRotation);
        }
    }
}

public class ActivateCommand extends KeyboardCommand
{
    Activator activators[0];
    fun @construct()
    {
        super.init("activate");
    }

    fun void addActivator(Activator a)
    {
        activators << a;
    }

    fun void run()
    {
        for( int i; i < activators.size(); i++ )
        {
            spork ~ activators[i].activate();
        }
    }
}

// -------------------------------------------------------------------//
// Code that does stuff //
GG.camera().orthographic();
GG.scene().backgroundColor(@(0.05, 0.05, 0.05));

RotateCommand rotate_command;
Keyboard.bind(rotate_command, GWindow.KEY_R);
ActivateCommand activate_command;
Keyboard.bind(activate_command, GWindow.KEY_SPACE);

Item cur_item[0];  // items on board
Grid grid(shape4);
//grid.position(2,-2);
//grid.scale(0.5);

// Generators
GPlane generators[3];
FlatMaterial gen_mat[3];
Item @ stock[3]; 
for( int i; i < 3; i++ )
{
    gen_mat[i].color(@(0.2, 0.3, 0.6));
    generators[i].material(gen_mat[i]);
    generators[i] --> GG.scene();
    generators[i].pos(@(-3.5, 1 - i));
    spawnAt(i);
}

// Trashcan
GPlane trash;
FlatMaterial trash_mat;
trash_mat.color(@(0.8, 0.2, 0.2));
trash.material(trash_mat);
trash --> GG.scene();
trash.pos(@(3, 2));



// DOES ALL THE MOUSE STUFF
// i wish i had chodash before writing this
fun void mouseHandler()
{

    0 => int active;
    Item active_item;
    while(true)
    {
        GG.nextFrame() => now;
        GG.camera().screenCoordToWorldPos(GWindow.mousePos(), 1) => vec3 mouse_pos;

        if(active)
        {
            active_item.pos(mouse_pos);
            rotate_command.setItem(active_item);
            for( int i; i < 3; i++ )
            {
                if(active_item == stock[i] && !isHovered(generators[i], mouse_pos))
                {
                    spawnAt(i);
                }
            }
            if(active_item.snap_state)
            {
                grid.snapOff(active_item);
            }
        }
        if(GWindow.mouseLeftDown())
        {
            {
                for( int i; i < cur_item.size(); i++ )
                {
                    if(isHovered(cur_item[i], mouse_pos))
                    {
                        1 => active;
                        cur_item[i] @=> active_item;
                    }
                }
            }
        }
        if(GWindow.mouseLeftUp())
        {
            if(active)
            {
                0 => active;
                if(Math.fabs(mouse_pos.x - trash.pos().x) < 0.5
                && Math.fabs(mouse_pos.y - trash.pos().y) < 0.5)
                {
                    active_item.buf =< dac;
                    active_item --< GG.scene();
                    for( int i; i < cur_item.size(); i++ )
                    {
                        if(cur_item[i] == active_item) 
                        { 
                            cur_item.erase(i); 
                            break; 
                        }
                    }
                }
                else
                {
                    grid.snapOn(active_item);
                    if(active_item.snap_state == 0
                    && Math.fabs(active_item.posX() - active_item.base_pos.x) < 0.05
                    && Math.fabs(active_item.posY() - active_item.base_pos.y) < 0.05)
                    {
                        active_item --< GG.scene();
                        active_item.buf =< dac;
                        for( int i; i < cur_item.size(); i++ )
                        {
                            if(cur_item[i] == active_item) 
                            { 
                                cur_item.erase(i); 
                                break; 
                            }
                        }
                    }
                }
                null @=> rotate_command.item;
            }
        }
    }
}
spork ~ mouseHandler();

// Graphics Loop
while(true)
{
    GG.nextFrame() => now;
    Keyboard.update();
    Tween.update();
}